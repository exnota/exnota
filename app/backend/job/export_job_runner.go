package job

import (
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
	time.Sleep(10 * time.Second)
	return nil
}
