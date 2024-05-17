package data

import (
	"fmt"
	"log/slog"
	"time"

	"exnota.com/backend/block"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type destinationWriter struct {
	app core.App
}

func NewDestinationWriter(app core.App) block.DestinationWriter {
	return &destinationWriter{app}
}

func (w *destinationWriter) Update(request block.DestinationUpdateRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	return w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(
			block.CollectionDestination,
			request.Id,
		)
		if err != nil {
			return fmt.Errorf("failed to find destination with id %v: %w", request.Id, err)
		}

		destination, err := block.LoadDestination(record, w.app)
		if err != nil {
			return err
		}
		destination.SetName(request.Name)
		err = destination.SetExternalNotionStatus(request.NotionStatus)
		if err != nil {
			return err
		}

		if err := destination.ValidateAndSubmit(txDao); err != nil {
			return fmt.Errorf(
				"validate and submit failed for destination with id %v: %w",
				request.Id,
				err,
			)
		}

		return nil
	})
}

func (w *destinationWriter) ArchiveForWorkspace(workspaceId string) error {
	slog.Info("Archiving destinations for workspace", "workspace", workspaceId)

	return w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		filter, err := filter.CreateAndFilter(filter.Field{
			Name:  block.DestinationFieldWorkspace,
			Op:    filter.OpEquals,
			Value: workspaceId,
		})
		if err != nil {
			return err
		}

		destinations, err := txDao.FindRecordsByFilter(
			block.CollectionDestination,
			filter.Filter,
			"",
			0,
			0,
			filter.Params,
		)
		if err != nil {
			return fmt.Errorf("failed to find destinations for workspace %v: %w", workspaceId, err)
		}

		now := time.Now()
		for _, d := range destinations {
			slog.Info("Archiving destination", "destination", d.Id)
			destination, err := block.LoadDestination(d, w.app)
			if err != nil {
				return err
			}

			destination.SetArchived(now)
			err = destination.ValidateAndSubmit(txDao)
			if err != nil {
				return fmt.Errorf("failed to archive destination %v: %w", destination.Id(), err)
			}
		}

		return nil
	})
}
