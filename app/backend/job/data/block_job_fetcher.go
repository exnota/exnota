package data

import (
	"log/slog"

	filter "exnota.com/backend/lib/data"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
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
		Value: BlockJobStatusRunning,
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
		r.Set(BlockJobFieldStatus, BlockJobStatusWaiting)
		form := forms.NewRecordUpsert(f.app, r)
		err := form.Validate()
		if err != nil {
			slog.Error("Error validating block job setting status to waiting",
				"id", r.Id,
				"error", err,
			)
			continue
		}

		err = form.Submit()
		if err != nil {
			slog.Error("Error submitting new block job status to waiting",
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
			Value: BlockJobStatusWaiting,
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
		blockJob := LoadBlockJob(r)
		blocks = append(blocks, blockJob)
	}

	return blocks, nil
}
