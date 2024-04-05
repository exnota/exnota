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
	blockJobId string
	blockId    string
	app        core.App
}

func NewExportJobRunner(blockJobId string, blockId string, app core.App) ExportJobRunner {
	return &exportJobRunnerConfig{
		blockJobId: blockJobId,
		blockId:    blockId,
		app:        app,
	}
}

func (j *exportJobRunnerConfig) Run(job data.BlockJob, app core.App) error {
	time.Sleep(10 * time.Second)
	return nil
}
