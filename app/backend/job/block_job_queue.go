package job

import (
	"log/slog"
	"strconv"
	"sync"
	"time"

	"exnota.com/backend/job/data"
	"github.com/pocketbase/pocketbase/core"
)

const (
	NUM_EXPORT_WORKERS        = 6
	NUM_TRANSCRIPTION_WORKERS = 1
)

const (
	// When changing this, ensure it works reasonably with the backoff strategy
	// in job/block_job_processor.go
	MAX_ERROR_COUNT = 10
)

type BlockJobQueue interface {
	Start() error
}

type blockJobQueue struct {
	app             core.App
	exportJobRunner ExportJobRunner
}

func NewBlockJobQueue(app core.App, exportJobRunner ExportJobRunner) BlockJobQueue {
	return &blockJobQueue{app, exportJobRunner}
}

// Based on https://gobyexample.com/worker-pools
//
// To help debugging, you can use a reduced version in tool/job_queue/main.go.
func (j *blockJobQueue) Start() error {
	blockJobWriter := data.NewBlockJobWriter(j.app)
	err := blockJobWriter.ResetRunningJobs()
	if err != nil {
		return err
	}

	terminate := make(chan bool)
	j.app.OnTerminate().Add(func(e *core.TerminateEvent) error {
		terminate <- true
		return nil
	})

	go func() {
		poolManager := NewPoolManager(j.app, j.exportJobRunner)
		poolManager.Start()

		blockJobFetcher := data.NewBlockJobFetcher(j.app)

		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-terminate:
				slog.Info("[block job queue] Received terminate signal")
				// Return from the goroutine. This escapes the otherwise
				// infinite for loop.
				return
			case <-ticker.C:
				slog.Info("[block job queue] tick")
				// Always fetch at least as many jobs per type as there are workers.
				//
				// E.g. if there are 5 export workers and 1 transcription worker and
				// we fetch 10 jobs at a time, but all 10 happen to be transcription
				// jobs, then the export workers will be idle.
				//
				// Additionally, if there are 5 export workers and we fetch 3 export
				// jobs, those 3 might actually already be in progress according to
				// the jobsInProgress map, but not in progress according to the
				// database (i.e. they have been started but not yet had their
				// status set to 'running' in the database). So they will be
				// skipped by the Pool Manager and the 2 remaining works will be
				// idle, even if the database contains another 2 export jobs that
				// could be processed.
				jobs, err := blockJobFetcher.ListJobsToProcess()
				if err != nil {
					slog.Error("[block job queue] Error fetching jobs to process", "error", err)
					continue
				}

				slog.Info(
					"[block job queue] Fetched num jobs to process",
					"count",
					len(jobs))
				jobDetails := make([]interface{}, 0, len(jobs)*4)
				for i, job := range jobs {
					jobDetails = append(
						jobDetails,
						strconv.Itoa(i),
						job.ID(),
						"type",
						job.Type(),
					)
				}
				if len(jobs) > 0 {
					slog.Info(
						"[block job queue] Fetched these jobs to process",
						jobDetails...)
				}
				poolManager.AddJobs(jobs)
			}
		}
	}()

	return nil
}

// Manages the allocation of jobs to worker pools.
type PoolManager interface {
	Start()
	AddJobs(jobs []data.BlockJob)
}

type poolManager struct {
	app             core.App
	exportJobRunner ExportJobRunner
	// jobsInProgress should be a pointer in case it needs to be passed around,
	// as the mutex property should not be passed by value.
	jobsInProgress    *jobsInProgress
	exportPool        chan data.BlockJob
	transcriptionPool chan data.BlockJob
	completions       chan string
}

func NewPoolManager(app core.App, exportJobRunner ExportJobRunner) PoolManager {
	jip := jobsInProgress{
		m: make(map[string]struct{}),
	}
	exportPool := make(chan data.BlockJob)
	transcriptionPool := make(chan data.BlockJob)
	completions := make(chan string)

	return &poolManager{
		app,
		exportJobRunner,
		&jip,
		exportPool,
		transcriptionPool,
		completions,
	}
}

func (pm *poolManager) Start() {
	for w := 1; w <= NUM_EXPORT_WORKERS; w++ {
		go exportWorker(w, pm.exportPool, pm.completions, pm.app, pm.exportJobRunner)
	}
	for w := 1; w <= NUM_TRANSCRIPTION_WORKERS; w++ {
		go transcriptionWorker(w, pm.transcriptionPool, pm.completions, pm.app)
	}

	go func() {
		for jobID := range pm.completions {
			pm.jobsInProgress.Remove(jobID)
		}
	}()
}

func (pm *poolManager) AddJobs(jobs []data.BlockJob) {
	for _, job := range jobs {
		// Lock between checking if job is in progress and adding it to
		// in progress. This prevents a job being processed twice if two
		// goroutines check if it's in progress at the same time.
		pm.jobsInProgress.Lock()
		if pm.jobsInProgress.ContainsWithoutLock(job.ID()) {
			slog.Info(
				"[pool manager] Already in progress, skipping.",
				"id", job.ID(),
				"block", job.Block(),
				"type", job.Type(),
			)
		} else {
			switch job.Type() {
			case data.BlockJobTypeExport:
				// Use non-blocking 'select' (with default case) for sending
				// jobs to the channel pools. This prevents the scenario where
				// attempting to add a job to a full pool causes the goroutine
				// to block and jobs can't be added to the other pool.
				//
				// This was happening when using a simple `pm.poolOne <- job`
				// instead of the select statement.
				//
				// https://gobyexample.com/non-blocking-channel-operations
				select {
				case pm.exportPool <- job:
					pm.jobsInProgress.AddWithoutLock(job.ID())
					slog.Info("[pool manager] Added to export pool", "id", job.ID())
				default:
					slog.Info("[pool manager] Export pool is full. Skipping.", "id", job.ID())
				}
			case data.BlockJobTypeTranscription:
				// Use non-blocking 'select' (with default case) for sending
				// jobs to the channel pools. This prevents the scenario where
				// attempting to add a job to a full pool causes the goroutine
				// to block and jobs can't be added to the other pool.
				//
				// This was happening when using a simple `pm.poolOne <- job`
				// instead of the select statement.
				//
				// https://gobyexample.com/non-blocking-channel-operations
				select {
				case pm.transcriptionPool <- job:
					pm.jobsInProgress.AddWithoutLock(job.ID())
					slog.Info("[pool manager] Added to transcription pool", "id", job.ID())
				default:
					slog.Info("[pool manager] Transcription pool is full. Skipping.", "id", job.ID())
				}

			default:
				slog.Error("[pool manager] Unknown job type", "type", job.Type())
			}
		}
		pm.jobsInProgress.Unlock()
	}
}

func exportWorker(
	workerId int,
	jobs <-chan data.BlockJob,
	completions chan<- string,
	app core.App,
	exportRunner ExportJobRunner,
) {
	for j := range jobs {
		slog.Info(
			"[export worker] Received job",
			"worker id",
			workerId,
			"block job id",
			j.ID(),
			"block id",
			j.Block(),
		)

		// The processor handles the status and panics of the runner
		processor := NewBlockJobProcessor(app)
		err := processor.Process(j.ID(), exportRunner)
		if err != nil {
			slog.Warn(
				"[export worker] Job errored",
				"worker id",
				workerId,
				"block job id",
				j.ID(),
				"block id",
				j.Block(),
				"error",
				err,
			)
			continue
		}

		slog.Info(
			"[export worker] Job completed",
			"worker id",
			workerId,
			"block job id",
			j.ID(),
			"block id",
			j.Block(),
		)
		completions <- j.ID()
	}
}

func transcriptionWorker(
	workerId int,
	jobs <-chan data.BlockJob,
	completed chan<- string,
	app core.App,
) {
	for j := range jobs {
		slog.Info(
			"[transcription worker] Received job",
			"worker id",
			workerId,
			"block job id",
			j.ID(),
			"block id",
			j.Block(),
		)

		// The processor handles the status and panics of the runner
		processor := NewBlockJobProcessor(app)
		transcriptionRunner := NewTranscriptionJobRunner(app)
		err := processor.Process(j.ID(), transcriptionRunner)
		if err != nil {
			slog.Warn(
				"[transcription worker] Job errored",
				"worker id",
				workerId,
				"block job id",
				j.ID(),
				"block id",
				j.Block(),
				"error",
				err,
			)
			continue
		}

		slog.Info(
			"[transcription worker] Job completed",
			"worker id",
			workerId,
			"block job id",
			j.ID(),
			"block id",
			j.Block(),
		)
		completed <- j.ID()
	}
}

// Tracks jobs that are in progress, across multiple goroutines.
//
// This is used instead of checking the job status via the database, which is
// susceptible to race conditions where a job that has been added to
// a worker is added again to a second worker before the first has set its
// status in the database to running.
//
// Using a mutex unlock/lock allows checking the status of a job and adding it
// to the in progress map to be atomic.
//
// With recent refactorings this may be an unlikely scenario, but it was a
// reproducable issue in the past.
type jobsInProgress struct {
	mu sync.Mutex
	m  map[string]struct{}
}

func (i *jobsInProgress) Lock() {
	i.mu.Lock()
}

func (i *jobsInProgress) Unlock() {
	i.mu.Unlock()
}

func (i *jobsInProgress) ContainsWithoutLock(id string) bool {
	_, ok := i.m[id]
	return ok
}

func (jip *jobsInProgress) AddWithoutLock(id string) {
	jip.m[id] = struct{}{}
}

func (jip *jobsInProgress) Remove(id string) {
	jip.mu.Lock()
	defer jip.mu.Unlock()
	delete(jip.m, id)
}
