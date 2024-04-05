package job

import (
	"log/slog"
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
	app core.App
}

func NewBlockJobQueue(app core.App) BlockJobQueue {
	return &blockJobQueue{
		app: app,
	}
}

// run method
func (j *blockJobQueue) Start() error {
	blockJobFetcher := data.NewBlockJobFetcher(j.app)
	err := blockJobFetcher.ResetRunningJobs()
	if err != nil {
		return err
	}

	exportQueue := make(chan data.BlockJob)
	// Might not need this, but have left it because I'm not familiar with
	// channel patterns and it could be useful
	exportResults := make(chan string)
	for w := 1; w <= NUM_EXPORT_WORKERS; w++ {
		go exportWorker(w, exportQueue, exportResults, j.app)
	}

	transcriptionQueue := make(chan data.BlockJob)
	// Might not need this, but have left it because I'm not familiar with
	// channel patterns and it could be useful
	transcriptionResults := make(chan string)
	for w := 1; w <= NUM_TRANSCRIPTION_WORKERS; w++ {
		go transcriptionWorker(w, transcriptionQueue, transcriptionResults, j.app)
	}

	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			jobs, err := blockJobFetcher.ListJobsToProcess(MAX_ERROR_COUNT)
			if err != nil {
				slog.Error("Error fetching jobs to process", "error", err)
				continue
			}
			slog.Info("Fetched jobs to process", "count", len(jobs))

			for _, job := range jobs {
				switch job.Type() {
				case data.BlockJobTypeExport:
					slog.Info("⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️")
					slog.Info("Adding export job to queue")
					slog.Info("⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️ ⬆️")
					exportQueue <- job
				case data.BlockJobTypeTranscription:
					slog.Info("🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ ")
					slog.Info("Adding transcription job to queue")
					slog.Info("🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ 🎙️ ")
					transcriptionQueue <- job
				default:
					slog.Error("Unknown job type", "type", job.Type())
				}
			}
		}
	}()

	return nil
}

func exportWorker(id int, jobs <-chan data.BlockJob, _ chan<- string, app core.App) {
	for j := range jobs {
		slog.Info("[export worker] Received job", "worker id", id, "block job id", j.ID(), "block id", j.Block())

		// The processor handles the status and panics of the runner
		processor := NewBlockJobProcessor(app)
		exportRunner := NewExportJobRunner(app)
		err := processor.Process(j, exportRunner)
		if err != nil {
			slog.Warn("[export worker] Job errored", "worker id", id, "block job id", j.ID(), "block id", j.Block(), "error", err)
			continue
		}

		// results <- "done"
		slog.Info("[export worker] Job completed", "worker id", id, "block job id", j.ID(), "block id", j.Block())
	}
}

func transcriptionWorker(id int, jobs <-chan data.BlockJob, _ chan<- string, app core.App) {
	for j := range jobs {
		slog.Info("[transcription worker] Received job", "worker id", id, "block job id", j.ID(), "block id", j.Block())

		// The processor handles the status and panics of the runner
		processor := NewBlockJobProcessor(app)
		transcriptionRunner := NewTranscriptionJobRunner(app)
		err := processor.Process(j, transcriptionRunner)
		if err != nil {
			slog.Warn("[transcription worker] Job errored", "worker id", id, "block job id", j.ID(), "block id", j.Block(), "error", err)
			continue
		}

		// results <- "done"
		slog.Info("[transcription worker] Job completed", "worker id", id, "block job id", j.ID(), "block id", j.Block())
	}
}
