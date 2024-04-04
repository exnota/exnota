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

	go func() {
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			jobs, err := blockJobFetcher.ListJobsToProcess()
			if err != nil {
				slog.Error("Error fetching jobs to process", "error", err)
				continue
			}
			slog.Info("Fetched jobs to process", "count", len(jobs))

			for _, job := range jobs {
				switch job.Type() {
				case data.BlockJobTypeExport:
					slog.Info("⬆️ Adding export job to queue")
					exportQueue <- job
				case data.BlockJobTypeTranscription:
					slog.Info("🎙️ Nothing is done for job of type transcription")
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

		runner := NewExportJobRunner(j.ID(), j.Block(), app)
		err := runner.Run()
		if err != nil {
			slog.Info("[export worker] Job errored", "worker id", id, "block job id", j.ID(), "block id", j.Block(), "error", err)
			continue
		}

		// results <- "done"
		slog.Info("[export worker] Job completed", "worker id", id, "block job id", j.ID(), "block id", j.Block())
	}
}
