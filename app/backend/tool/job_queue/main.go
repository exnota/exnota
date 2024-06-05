package main

import (
	"log/slog"
	"sync"
	"time"
)

// This is a reduced version of the app code for testing and debugging job
// queues.
//
// Before using it for troubleshooting, ensure that it's a good representation
// of the app code.
func main() {
	slog.Info("[main] Starting")

	// Simulate the app being terminated
	done := make(chan bool)
	go func() {
		slog.Info("[main] Sleeping")
		time.Sleep(30 * time.Second)
		done <- true
	}()

	slog.Info("[main] Starting pool manager")
	scenario := getBlockedPoolOneScenario()
	data := scenario.dataStore
	poolManager := NewPoolManager(scenario.dataStore)
	poolManager.Start(scenario.poolOneSize, scenario.poolTwoSize)

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-done:
			slog.Info("[main] Received from done")
			// Return. This escapes the otherwise infinite for loop.
			return
		case <-ticker.C:
			slog.Info("[main] tick")
			nextJobs := data.Get(scenario.dataBatchSize)
			if len(nextJobs) > 0 {
				poolManager.AddJobs(nextJobs)
			}
		}
	}
}

type scenario struct {
	dataStore     *DataStore
	dataBatchSize int
	poolOneSize   int
	poolTwoSize   int
}

// Tests that if:
// a) Pool one is full (job 1), and
// b) Another job is attempted to be added to pool one (job 2), then
// c) This does not block the adding of jobs to pool two (jobs 3, 4, etc)
func getBlockedPoolOneScenario() scenario {
	data := DataStore{
		jobs: []Job{
			{
				id:              "1",
				pool:            1,
				durationSeconds: 10,
			},
			{
				id:              "2",
				pool:            1,
				durationSeconds: 10,
			},
			{
				id:              "3",
				pool:            2,
				durationSeconds: 1,
			},
			{
				id:              "4",
				pool:            2,
				durationSeconds: 1,
			},
			{
				id:              "5",
				pool:            2,
				durationSeconds: 1,
			},
			{
				id:              "6",
				pool:            2,
				durationSeconds: 1,
			},
			{
				id:              "7",
				pool:            2,
				durationSeconds: 1,
			},
			{
				id:              "8",
				pool:            2,
				durationSeconds: 1,
			},
		},
	}

	return scenario{
		dataStore:     &data,
		dataBatchSize: 6,
		poolOneSize:   1,
		poolTwoSize:   2,
	}
}

// Manages the allocation of jobs to worker pools.
type PoolManager interface {
	Start(poolOneSize int, poolTwoSize int)
	AddJobs(jobs []Job)
}

type poolManager struct {
	jobsInProgress *jobsInProgress
	poolOne        chan Job
	poolTwo        chan Job
	completions    chan string
	dataStore      *DataStore
}

func NewPoolManager(dataStore *DataStore) PoolManager {
	jipMap := make(map[string]struct{})
	jip := jobsInProgress{
		m: jipMap,
	}

	poolOne := make(chan Job)
	poolTwo := make(chan Job)
	completions := make(chan string)

	return &poolManager{
		&jip,
		poolOne,
		poolTwo,
		completions,
		dataStore,
	}
}

func (pm *poolManager) Start(poolOneSize int, poolTwoSize int) {
	for w := 1; w <= poolOneSize; w++ {
		slog.Info("[PoolManager.Start] Starting pool 1 worker", "worker id", w)
		go poolWorker("pool 1", w, pm.poolOne, pm.completions, pm.dataStore)
		slog.Info("[PoolManager.Start] Created pool 1 worker", "worker id", w)
	}
	for w := 1; w <= poolTwoSize; w++ {
		slog.Info("[PoolManager.Start] Starting pool 2 worker", "worker id", w)
		go poolWorker("pool 2", w, pm.poolTwo, pm.completions, pm.dataStore)
		slog.Info("[PoolManager.Start] Created pool 2 worker", "worker id", w)
	}

	go func() {
		for jobID := range pm.completions {
			slog.Info("[PoolManager.Start] Removing from in progress map", "id", jobID)
			pm.jobsInProgress.Remove(jobID)
		}
	}()
}

func (pm *poolManager) AddJobs(jobs []Job) {
	for _, job := range jobs {
		// Lock between checking if job is in progress and adding it to
		// in progress. This prevents a job being processed twice if two
		// goroutines check if it's in progress at the same time.
		pm.jobsInProgress.Lock()
		slog.Info("[PoolManager.AddJobs] Locked", "id", job.id)
		if pm.jobsInProgress.ContainsWithoutLock(job.id) {
			slog.Info(
				"[PoolManager.AddJobs] Already in in progress map",
				"id",
				job.id,
			)
		} else {
			if job.pool == 1 {
				slog.Info("[PoolManager.AddJobs] Sending to pool one", "id", job.id)
				// Use non-blocking 'select' for sending jobs to the channel
				// pools. This prevents the scenario where attempting to add
				// a job to a full pool causes the goroutine to block and jobs
				// can't be added to the other pool.
				//
				// This was happening when using a simple `pm.poolOne <- job`
				// instead of the select statement.
				//
				// https://gobyexample.com/non-blocking-channel-operations
				select {
				case pm.poolOne <- job:
					pm.jobsInProgress.AddWithoutLock(job.id)
					slog.Info("[PoolManager.AddJobs] Sent to pool one", "id", job.id)
				default:
					slog.Info("[PoolManager.AddJobs] Pool one is full. Skipping.", "id", job.id)
				}
			} else {
				slog.Info("[PoolManager.AddJobs] Sending to pool two", "id", job.id)
				// Use non-blocking 'select' for sending jobs to the channel
				// pools. This prevents the scenario where attempting to add
				// a job to a full pool causes the goroutine to block and jobs
				// can't be added to the other pool.
				//
				// This was happening when using a simple `pm.poolOne <- job`
				// instead of the select statement.
				//
				// https://gobyexample.com/non-blocking-channel-operations
				select {
				case pm.poolTwo <- job:
					pm.jobsInProgress.AddWithoutLock(job.id)
					slog.Info("[PoolManager.AddJobs] Sent to pool two", "id", job.id)
				default:
					slog.Info("[PoolManager.AddJobs] Pool two is full. Skipping.", "id", job.id)
				}
			}
		}
		pm.jobsInProgress.Unlock()
		slog.Info("[PoolManager.AddJobs] Unlocked", "id", job.id)
	}
}

func poolWorker(
	pool string,
	id int,
	jobs <-chan Job,
	completions chan<- string,
	dataStore *DataStore,
) {
	for j := range jobs {
		slog.Info(
			"[worker] Started for job",
			"pool",
			pool,
			"worker id",
			id,
			"job id",
			j.id,
		)

		time.Sleep(time.Duration(j.durationSeconds) * time.Second)
		dataStore.MarkCompleted(j.id)

		slog.Info(
			"[worker] Finished for job",
			"pool",
			pool,
			"worker id",
			id,
			"job id",
			j.id,
		)
		completions <- j.id
		slog.Info(
			"[worker] Sent completion",
			"pool",
			pool,
			"worker id",
			id,
			"job id",
			j.id,
		)
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

func (i *jobsInProgress) AddWithoutLock(id string) {
	i.m[id] = struct{}{}
}

func (i *jobsInProgress) Remove(id string) {
	slog.Info("[JobsinProgress.Remove] Removing from in progress map", "id", id)
	i.mu.Lock()
	slog.Info("[JobsinProgress.Remove] Locked", "id", id)
	defer func() {
		i.mu.Unlock()
		slog.Info("[JobsinProgress.Remove] Unlocked", "id", id)
	}()
	delete(i.m, id)
}

// DataStore is used to simulate a database of jobs.
type DataStore struct {
	mu        sync.Mutex
	jobs      []Job
	completed []string
}

type Job struct {
	id string
	// 1 or 2 (for poolOne or poolTwo)
	//
	// This is a substitute for the *type* of job.
	pool int
	// how long job should take
	durationSeconds int
}

func (d *DataStore) Get(num int) []Job {
	slog.Info(
		"[DataStore.Get] Getting jobs",
		"count",
		num,
	)
	d.mu.Lock()
	slog.Info("[DataStore.Get] Locked")
	defer func() {
		d.mu.Unlock()
		slog.Info("[DataStore.Get] Unlocked")
	}()
	var result []Job
	for _, job := range d.jobs {
		if !contains(d.completed, job.id) {
			result = append(result, job)
			if len(result) == num {
				break
			}
		}
	}
	slog.Info(
		"[DataStore.Get] Returning jobs",
		"count",
		len(result),
	)
	return result
}

func contains(slice []string, value string) bool {
	for _, item := range slice {
		if item == value {
			return true
		}
	}
	return false
}

func (d *DataStore) MarkCompleted(id string) {
	slog.Info("[DataStore.MarkCompleted] Marking job as completed", "id", id)
	d.mu.Lock()
	slog.Info("[DataStore.MarkCompleted] Locked")
	defer func() {
		d.mu.Unlock()
		slog.Info("[DataStore.MarkCompleted] Unlocked")
	}()
	d.completed = append(d.completed, id)
	slog.Info("[DataStore.MarkCompleted] Marked job complete", "id", id)
}
