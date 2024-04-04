package job

import (
	"exnota.com/backend/job/data"
	"github.com/pocketbase/pocketbase/core"
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

	// TODO: Every 1 second, query for jobs that meet the criteria
	// Criteria = 'waiting' status as 'next_run_at' <= now()
	// Add them to queue
	return nil
}
