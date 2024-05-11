package data

import (
	"fmt"

	"exnota.com/backend/block"
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
		err = destination.SetExternalStatus(request.Status)
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
