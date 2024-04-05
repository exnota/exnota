package job

import (
	"errors"
	"log/slog"

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
		statusErr := writer.SetStatusError(job.ID(), err)
		if statusErr != nil {
			return statusErr
		}
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
	writer := data.NewBlockJobWriter(j.app)
	statusErr := writer.SetStatusError(job.ID(), err)
	if statusErr != nil {
		slog.Error("error updating status", "error", statusErr)
	}
}
