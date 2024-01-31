package job

import (
	"time"

	"github.com/pocketbase/pocketbase/core"
)

type ExportJobRunner interface {
	Run() error
}

type ExportJobRunnerConfig struct {
	blockJobId string
	blockId    string
	app        core.App
}

func NewExportJobRunner(blockJobId string, blockId string, app core.App) ExportJobRunner {
	return &ExportJobRunnerConfig{
		blockJobId: blockJobId,
		blockId:    blockId,
		app:        app,
	}
}

// run method
func (j *ExportJobRunnerConfig) Run() error {
	// TODO: Implement with a simple status = running, wait, status = complete
	time.Sleep(5 * time.Second)

	return nil
}
