package job

import (
	"log/slog"
	"strconv"
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
func (j *blockJobQueue) Start() error {
	blockJobWriter := data.NewBlockJobWriter(j.app)
	err := blockJobWriter.ResetRunningJobs()
	if err != nil {
		return err
	}

	queue := newQueue(j.app, j.exportJobRunner)
	queue.Start()

	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()

		blockJobFetcher := data.NewBlockJobFetcher(j.app)
		for range ticker.C {
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

			queue.AddJobs(jobs)
		}
	}()

	return nil
}

type Queue interface {
	Start()
	AddJobs(jobs []data.BlockJob)
}

type queue struct {
	app                core.App
	exportJobRunner    ExportJobRunner
	inProgress         map[string]struct{}
	exportQueue        chan data.BlockJob
	transcriptionQueue chan data.BlockJob
	completed          chan string
}

func newQueue(app core.App, exportJobRunner ExportJobRunner) Queue {
	inProgress := make(map[string]struct{})

	exportQueue := make(chan data.BlockJob)
	transcriptionQueue := make(chan data.BlockJob)
	completed := make(chan string)

	return &queue{
		app,
		exportJobRunner,
		inProgress,
		exportQueue,
		transcriptionQueue,
		completed,
	}
}

func (q *queue) Start() {
	for w := 1; w <= NUM_EXPORT_WORKERS; w++ {
		go exportWorker(w, q.exportQueue, q.completed, q.app, q.exportJobRunner)
	}
	for w := 1; w <= NUM_TRANSCRIPTION_WORKERS; w++ {
		go transcriptionWorker(w, q.transcriptionQueue, q.completed, q.app)
	}

	go func() {
		for jobID := range q.completed {
			slog.Info("[block job queue] 🗺️ Removing from completed map", "jobID", jobID)
			delete(q.inProgress, jobID)
		}
	}()
}

func (q *queue) AddJobs(jobs []data.BlockJob) {
	for _, job := range jobs {
		if _, ok := q.inProgress[job.ID()]; ok {
			slog.Info(
				"[block job queue] 🗺️ Already in completed map",
				"id",
				job.ID(),
				"block",
				job.Block(),
				"type",
				job.Type(),
			)
			continue
		}

		slog.Info(
			"[block job queue] 🗺️ Setting to completed map",
			"id",
			job.ID(),
		)
		q.inProgress[job.ID()] = struct{}{}

		switch job.Type() {
		case data.BlockJobTypeExport:
			q.exportQueue <- job
		case data.BlockJobTypeTranscription:
			q.transcriptionQueue <- job
		default:
			slog.Error("[block job queue] Unknown job type", "type", job.Type())
		}
	}
}

func exportWorker(
	id int,
	jobs <-chan data.BlockJob,
	completed chan<- string,
	app core.App,
	exportRunner ExportJobRunner,
) {
	for j := range jobs {
		slog.Info(
			"[export worker] Received job",
			"worker id",
			id,
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
				id,
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
			id,
			"block job id",
			j.ID(),
			"block id",
			j.Block(),
		)
		completed <- j.ID()
	}
}

func transcriptionWorker(id int, jobs <-chan data.BlockJob, completed chan<- string, app core.App) {
	for j := range jobs {
		slog.Info(
			"[transcription worker] Received job",
			"worker id",
			id,
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
				id,
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
			id,
			"block job id",
			j.ID(),
			"block id",
			j.Block(),
		)
		completed <- j.ID()
	}
}
