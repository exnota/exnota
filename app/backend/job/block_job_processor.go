package job

import (
	"errors"
	"log/slog"
	"math"
	"time"

	"exnota.com/backend/job/data"
	"github.com/pocketbase/pocketbase/core"
)

type BlockJobProcessor interface {
	Process(job data.BlockJob, runnable RunnableBlockJob) error
}

type blockJobProcessor struct {
	app core.App
}

func NewBlockJobProcessor(app core.App) BlockJobProcessor {
	return &blockJobProcessor{
		app: app,
	}
}

type RunnableBlockJob interface {
	Run(job data.BlockJob, app core.App) error
}

func (j *blockJobProcessor) Process(job data.BlockJob, runnable RunnableBlockJob) (err error) {
	writer := data.NewBlockJobWriter(j.app)

	err = writer.SetStatusRunning(job.ID())
	if err != nil {
		// Don't need to set job status to errorred as it was unlikely to have
		// been set to running if the last call failed.
		return err
	}

	// Handle panics from the runnable
	defer func() {
		if r := recover(); r != nil {
			// `err` is the named return variable, so it will be returned
			// without an explicit return statement.
			err = errors.New("panic in runnable.Run")
			j.handleError(job, err)
		}
	}()

	err = runnable.Run(job, j.app)
	if err != nil {
		j.handleError(job, err)
		return err
	}

	err = writer.SetStatusComplete(job.ID())
	if err != nil {
		// Don't bother setting status to error if setting status to complete
		// fails. It might have the same underlying error and it won't
		// enable a better recovery path.
		return err
	}

	// This error may come from the defer call
	return err
}

func (j *blockJobProcessor) handleError(job data.BlockJob, err error) {
	// The backoff logic below should progress like this (generate this using:
	// https://go.dev/play/p/4Pn10aAcY3h):
	//
	// 3s
	// 9s
	// 27s
	// 1m21s
	// 4m3s
	// 12m9s
	// 36m27s
	// 1h49m21s
	// 5h28m3s
	// 16h24m9s
	errorCount := job.ErrorCount()
	nextRunAt := time.Now().Add(time.Duration(math.Pow(3, float64(errorCount+1))) * 1 * time.Second)

	writer := data.NewBlockJobWriter(j.app)
	statusErr := writer.SetStatusError(job.ID(), nextRunAt, err)
	if statusErr != nil {
		slog.Error("error updating status", "error", statusErr)
	}
}
