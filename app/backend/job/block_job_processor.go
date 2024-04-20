package job

import (
	"errors"
	"fmt"
	"log/slog"
	"math"
	"runtime/debug"
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
	// Runs the job and returns the summary result.
	Run(job data.BlockJob, app core.App) (data.Summary, error)
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
			stack := debug.Stack()
			// `err` is the named return variable of this method, so assiging
			// the panic error to it will mean it can be returned from this
			// method without an explicit return statement (which the defer()
			// function doesn't seem to allow).
			if rErr, ok := r.(error); ok {
				err = rErr
			} else if rStr, ok := r.(string); ok {
				err = errors.New(rStr)
			} else {
				err = fmt.Errorf("unknown panic caught of type: %T", r)
			}

			j.handleError(job, err, &stack)
		}
	}()

	summary, err := runnable.Run(job, j.app)
	if err != nil {
		j.handleError(job, err, nil)
		return err
	}

	err = writer.SetStatusComplete(job.ID(), summary)
	if err != nil {
		// Don't bother setting status to error if setting status to complete
		// fails. It might have the same underlying error and it won't
		// enable a better recovery path.
		return err
	}

	// This error may come from the defer call
	return err
}

func (j *blockJobProcessor) handleError(job data.BlockJob, err error, stack *[]byte) {
	if stack != nil {
		slog.Error("Stack trace for error", "error", err, "stack", stack)
		fmt.Println(string(*stack))
	} else {
		slog.Error("Stack trace for error", "error", err)
	}
	// Also print to console because the slog output will be on one line.

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
