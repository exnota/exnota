package data

import (
	"log/slog"

	"exnota.com/backend/lib/data/field"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type BlockJobFetcher interface {
	ListJobsToProcess() ([]BlockJob, error)
	ListExportJobs(request ListExportJobsRequest) ([]BlockJob, error)
	ListJobs(request ListJobsRequest) ([]BlockJob, error)
}

type blockJobFetcher struct {
	app core.App
}

func NewBlockJobFetcher(app core.App) BlockJobFetcher {
	return &blockJobFetcher{app}
}

func (f *blockJobFetcher) ListJobsToProcess() ([]BlockJob, error) {
	// Jobs that are waiting or have errored less than their max error count
	filter, err := filter.CreateAndFilter(
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
		filter.Filter,
		"+"+field.DefaultFieldCreated,
		0,
		0,
		filter.Params,
	)
	if err != nil {
		return nil, err
	}

	var blocks []BlockJob
	for _, r := range records {
		blockJob, err := LoadBlockJob(r, f.app)
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

type ListExportJobsRequest struct {
	BlockId string           `validate:"required"`
	UserId  string           `validate:"required"`
	Command ExportJobCommand `validate:"required"`
	Status  BlockJobStatus   `validate:"required"`
}

func (f *blockJobFetcher) ListExportJobs(request ListExportJobsRequest) ([]BlockJob, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	// It may be possible to add a JSON filter index, if necessary: https://github.com/pocketbase/pocketbase/issues/423#issuecomment-1258338542
	filter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  BlockJobFieldBlock,
			Op:    filter.OpEquals,
			Value: request.BlockId,
		},
		filter.Field{
			Name:  BlockJobFieldUser,
			Op:    filter.OpEquals,
			Value: request.UserId,
		},
		filter.Field{
			Name:  BlockJobExportConfigCommand,
			Op:    filter.OpEquals,
			Value: string(request.Command),
		},
		filter.Field{
			Name:  BlockJobFieldStatus,
			Op:    filter.OpEquals,
			Value: string(request.Status),
		},
	)
	if err != nil {
		return nil, err
	}

	records, err := f.app.Dao().FindRecordsByFilter(
		CollectionBlockJob,
		filter.Filter,
		"+"+field.DefaultFieldCreated,
		0,
		0,
		filter.Params,
	)
	if err != nil {
		return nil, err
	}

	var blocks []BlockJob
	for _, r := range records {
		blockJob, err := LoadBlockJob(r, f.app)
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

type ListJobsRequest struct {
	BlockId string `validate:"required"`
	UserId  string `validate:"required"`
	Type    *BlockJobType
	Status  *BlockJobStatus
}

func (f *blockJobFetcher) ListJobs(request ListJobsRequest) ([]BlockJob, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	filters := []filter.Field{
		{
			Name:  BlockJobFieldBlock,
			Op:    filter.OpEquals,
			Value: request.BlockId,
		},
		{
			Name:  BlockJobFieldUser,
			Op:    filter.OpEquals,
			Value: request.UserId,
		},
	}
	if request.Type != nil {
		filters = append(filters, filter.Field{
			Name:  BlockJobFieldType,
			Op:    filter.OpEquals,
			Value: string(*request.Type),
		})
	}
	if request.Status != nil {
		filters = append(filters, filter.Field{
			Name:  BlockJobFieldStatus,
			Op:    filter.OpEquals,
			Value: string(*request.Status),
		})
	}
	filter, err := filter.CreateAndFilter(filters...)
	if err != nil {
		return nil, err
	}

	records, err := f.app.Dao().FindRecordsByFilter(
		CollectionBlockJob,
		filter.Filter,
		"+"+field.DefaultFieldCreated,
		0,
		0,
		filter.Params,
	)
	if err != nil {
		return nil, err
	}

	var blocks []BlockJob
	for _, r := range records {
		blockJob, err := LoadBlockJob(r, f.app)
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
