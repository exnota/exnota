package data

import (
	"log/slog"

	"exnota.com/backend/lib/data/field"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type BlockJobFetcher interface {
	ListJobsToProcess(maxErrorCount int) ([]BlockJob, error)
}

type blockJobFetcher struct {
	app core.App
}

func NewBlockJobFetcher(app core.App) BlockJobFetcher {
	return &blockJobFetcher{app}
}

func (f *blockJobFetcher) ListJobsToProcess(maxErrorCount int) ([]BlockJob, error) {
	waitingFilter, err := filter.CreateAndFilter(
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

	errorFilter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  BlockJobFieldStatus,
			Op:    filter.OpEquals,
			Value: string(BlockJobStatusError),
		},
		filter.Field{
			Name:        BlockJobFieldNextRunAt,
			Op:          filter.OpLessThanEquals,
			ValuePreset: filter.ValuePresetNow,
		},
		filter.Field{
			Name:     BlockJobFieldErrorCount,
			Op:       filter.OpLessThan,
			ValueInt: &maxErrorCount,
		},
	)
	if err != nil {
		return nil, err
	}

	combinedFilter, err := filter.GroupFiltersWithOr(waitingFilter, errorFilter)
	if err != nil {
		return nil, err
	}

	records, err := f.app.Dao().FindRecordsByFilter(
		CollectionBlockJob,
		combinedFilter.Filter,
		"+"+field.DefaultFieldCreated,
		0,
		0,
		combinedFilter.Params,
	)
	if err != nil {
		return nil, err
	}

	var blocks []BlockJob
	for _, r := range records {
		blockJob, err := NewBlockJob(r, f.app)
		if err != nil {
			slog.Error("Error creating block job",
				"id", r.Id,
				"error", err,
			)
			continue
		}
		blocks = append(blocks, blockJob)
	}

	return blocks, nil
}
