package job

import (
	"fmt"
	"log/slog"
	"time"

	"exnota.com/backend/job/data"
	"github.com/pocketbase/pocketbase/core"
)

type ExportJobRunner interface {
	RunnableBlockJob
}

type exportJobRunnerConfig struct {
	app core.App
}

func NewExportJobRunner(app core.App) ExportJobRunner {
	return &exportJobRunnerConfig{
		app: app,
	}
}

func (j *exportJobRunnerConfig) Run(job data.BlockJob, app core.App) error {
	exportJob, err := data.NewExportBlockJob(job.Record(), app)
	if err != nil {
		return err
	}

	switch exportJob.(type) {
	case data.CreateVoiceNoteJob:
		// Do something
		slog.Info("Running create voice note job", "job", job)
		time.Sleep(5 * time.Second)
		return nil
	default:
		slog.Error("unknown export job type", "type", exportJob.Type())
		return fmt.Errorf("unknown export job type: %s", exportJob.Type())
	}
}
