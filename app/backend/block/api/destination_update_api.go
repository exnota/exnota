package api

import (
	"reflect"

	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type DestinationUpdateAPI interface {
	ApplyHooks()
}

type destinationUpdateAPI struct {
	app                core.App
	destinationFetcher block.DestinationFetcher
}

func NewDestinationUpdateAPI(
	app core.App,
	destinationFetcher block.DestinationFetcher,
) DestinationUpdateAPI {
	return &destinationUpdateAPI{
		app,
		destinationFetcher,
	}
}

func (h *destinationUpdateAPI) ApplyHooks() {
	h.app.OnRecordBeforeUpdateRequest(block.CollectionDestination).
		Add(func(e *core.RecordUpdateEvent) error {
			updatedDestination, err := block.LoadDestination(e.Record, h.app)
			if err != nil {
				return err
			}
			existingDestination, err := h.destinationFetcher.FetchById(updatedDestination.Id())
			if err != nil {
				return err
			}

			// Don't allow changing external field
			updatedExternal, err := updatedDestination.External()
			if err != nil {
				return err
			}
			existingExternal, err := existingDestination.External()
			if err != nil {
				return err
			}
			if !reflect.DeepEqual(updatedExternal, existingExternal) {
				return apis.NewBadRequestError(
					"Cannot change external on destination update",
					nil,
				)
			}

			return nil
		})
}
