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
	Process(jobID string, runnable RunnableBlockJob) error
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

// Accept job ID rather than job because the entity may be queued for a while.
func (j *blockJobProcessor) Process(jobID string, runnable RunnableBlockJob) (err error) {
	slog.Info(
		"[block job processor] Processing job",
		"job",
		jobID,
	)

	fetcher := data.NewBlockJobFetcher(j.app)
	job, err := fetcher.FetchById(jobID)
	if err != nil {
		return err
	}

	writer := data.NewBlockJobWriter(j.app)

	err = writer.SetStatusRunning(job.ID())
	if err != nil {
		// Don't need to set job status to errorred as it was unlikely to have
		// been set to running if the last call failed.
		return err
	}
	slog.Info(
		"[block job processor] Job set to running",
		"job",
		job.ID(),
		"type",
		job.Type(),
	)

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

	slog.Info(
		"[block job processor] Running job",
		"job",
		job.ID(),
		"type",
		job.Type(),
	)
	summary, err := runnable.Run(job, j.app)
	if err != nil {
		j.handleError(job, err, nil)
		return err
	}
	slog.Info(
		"[block job processor] Job completed",
		"job",
		job.ID(),
		"type",
		job.Type(),
	)

	err = writer.SetStatusComplete(job.ID(), summary)
	if err != nil {
		// Don't bother setting status to error if setting status to complete
		// fails. It might have the same underlying error and it won't
		// enable a better recovery path.
		return err
	}

	slog.Info(
		"[block job processor] Job set to complete",
		"job",
		job.ID(),
		"type",
		job.Type(),
	)

	// This error may come from the defer call
	return err
}

func (j *blockJobProcessor) handleError(job data.BlockJob, jobErr error, stack *[]byte) {
	if stack != nil {
		slog.Error("Stack trace for error", "error", jobErr, "stack", string(*stack))
		// Also print to console because the slog output will be on one line.
		fmt.Println(string(*stack))
	} else {
		slog.Error("Stack trace for error", "error", jobErr)
	}

	// Job should not be retried, if error count has reached the maximum.
	errorCount := job.ErrorCount()
	if errorCount+1 >= MAX_ERROR_COUNT {
		writer := data.NewBlockJobWriter(j.app)
		err := writer.SetStatusError(job.ID(), jobErr)
		if err != nil {
			slog.Error("error updating status", "error", err)
			// Panic because any issues setting job status need to be resolved
			// ASAP.
			panic(err)
		}
		return
	}

	// Job should be retried.
	//
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
	nextRunAt := time.Now().Add(time.Duration(math.Pow(3, float64(errorCount+1))) * 1 * time.Second)
	writer := data.NewBlockJobWriter(j.app)
	err := writer.SetStatusWaitingIncrementError(job.ID(), nextRunAt, jobErr)
	if err != nil {
		slog.Error("error updating status", "error", err)
		// Panic because any issues setting job status need to be resolved
		// ASAP.
		panic(err)
	}
}
