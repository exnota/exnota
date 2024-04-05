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

	err = writer.UpdateStatus(data.UpdateStatusRequest{
		Id:     job.ID(),
		Status: data.BlockJobStatusRunning,
	})
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
			slog.Error("panic in runnable.Run", "error", r)

			statusErr := writer.UpdateStatus(data.UpdateStatusRequest{
				Id:     job.ID(),
				Status: data.BlockJobStatusError,
				Error:  err,
			})
			if statusErr != nil {
				// The panic error is more important, so just log this one.
				slog.Error("error updating status", "error", statusErr)
			}
		}
	}()

	err = runnable.Run(job, j.app)
	if err != nil {
		statusErr := writer.UpdateStatus(data.UpdateStatusRequest{
			Id:     job.ID(),
			Status: data.BlockJobStatusError,
			Error:  err,
		})
		if statusErr != nil {
			return statusErr
		}
		return err
	}

	err = writer.UpdateStatus(data.UpdateStatusRequest{
		Id:     job.ID(),
		Status: data.BlockJobStatusComplete,
	})
	if err != nil {
		// Don't bother setting status to error if setting status to complete
		// fails. It might have the same underlying error and it won't
		// enable a better recovery path.
		return err
	}

	// This error may come from the defer call
	return err
}
