package data

import (
	"log/slog"

	filter "exnota.com/backend/lib/data"
	"github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
)

type BlockJobFetcher interface {
	FetchBlock(blockID string, integrationID string) (*notion.Block, error)
	ResetRunningJobs() error
}

type blockJobFetcher struct {
	app core.App
}

func NewBlockJobFetcher(app core.App) BlockJobFetcher {
	return &blockJobFetcher{app}
}

func (f *blockJobFetcher) FetchBlock(blockID string, integrationID string) (*notion.Block, error) {
	return nil, nil
}

func (f *blockJobFetcher) ResetRunningJobs() error {
	filter, params := filter.CreateAndFilter(filter.Field{
		Name:  BlockJobFieldStatus,
		Value: BlockJobStatusRunning,
	})
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
