package data

import (
	"log/slog"

	filter "exnota.com/backend/lib/data"
	"github.com/pocketbase/pocketbase/core"
)

type BlockJobFetcher interface {
	ResetRunningJobs() error
	ListJobsToProcess() ([]BlockJob, error)
}

type blockJobFetcher struct {
	app core.App
}

func NewBlockJobFetcher(app core.App) BlockJobFetcher {
	return &blockJobFetcher{app}
}

func (f *blockJobFetcher) ResetRunningJobs() error {
	filter, params, err := filter.CreateAndFilter(filter.Field{
		Name:  BlockJobFieldStatus,
		Op:    filter.OpEquals,
		Value: string(BlockJobStatusRunning),
	})
	if err != nil {
		return err
	}

	records, err := f.app.Dao().FindRecordsByFilter(
		CollectionBlockJob,
		filter,
		"+created",
		0,
		0,
		params,
	)
	if err != nil {
		return err
	}

	for _, r := range records {
		blockJob := NewBlockJob(r, f.app)
		blockJob.SetStatus(BlockJobStatusWaiting)
		err := blockJob.ValidateAndSubmit(f.app.Dao())
		if err != nil {
			slog.Error("Error setting block job status to waiting",
				"id", r.Id,
				"error", err,
			)
			continue
		}
	}

	return nil
}

func (f *blockJobFetcher) ListJobsToProcess() ([]BlockJob, error) {
	filter, params, err := filter.CreateAndFilter(
		filter.Field{
			Name:  BlockJobFieldStatus,
			Op:    filter.OpEquals,
			Value: string(BlockJobStatusWaiting),
		},
		filter.Field{
			Name:        BlockJobFieldNextRunAt,
			Op:          filter.OpLessThanEquals,
			ValuePreset: filter.ValuePresetNow,
		},
	)
	if err != nil {
		return nil, err
	}

	records, err := f.app.Dao().FindRecordsByFilter(
		CollectionBlockJob,
		filter,
		"+created",
		0,
		0,
		params,
	)
	if err != nil {
		return nil, err
	}

	var blocks []BlockJob
	for _, r := range records {
		blockJob := NewBlockJob(r, f.app)
		blocks = append(blocks, blockJob)
	}

	return blocks, nil
}
