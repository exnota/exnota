package integration

import (
	"database/sql"
	"fmt"
	"reflect"

	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationDestinationEvents interface {
	ApplyHooks()
}

type integrationDestinationEvents struct {
	app                           core.App
	listeners                     []lib_integ.IntegrationDestinationEventListener
	integrationDestinationFetcher IntegrationDestinationFetcher
}

func NewIntegrationDestinationEvents(
	app core.App,
	listeners []lib_integ.IntegrationDestinationEventListener,
	integrationDestinationFetcher IntegrationDestinationFetcher,
) IntegrationDestinationEvents {
	return &integrationDestinationEvents{app, listeners, integrationDestinationFetcher}
}

func (h *integrationDestinationEvents) ApplyHooks() {
	// Notion
	h.app.OnModelAfterUpdate(
		CollectionIntegrationNotionObject).Add(
		func(e *core.ModelEvent) error {
			updatedRecord := e.Model.(*models.Record)

			// Skip if object is not used for a destination
			integrationDestination, err := h.integrationDestinationFetcher.FetchByExternalId(
				updatedRecord.Id,
			)
			if err != nil {
				if err == sql.ErrNoRows {
					return nil
				}
				return fmt.Errorf(
					"Error fetching integration destination for external record %v: %w",
					updatedRecord.Id,
					err,
				)
			}

			prevObject := LoadIntegrationNotionObject(updatedRecord.OriginalCopy(), h.app)
			prev := lib_integ.IntegrationDestinationState{
				Name:               prevObject.Title(),
				NotionObjectStatus: prevObject.Status(),
			}
			nextObject := LoadIntegrationNotionObject(updatedRecord, h.app)
			next := lib_integ.IntegrationDestinationState{
				Name:               nextObject.Title(),
				NotionObjectStatus: nextObject.Status(),
			}
			event := lib_integ.IntegrationDestinationEvent{
				Id:   integrationDestination.DestinationId(),
				Prev: prev,
				Next: next,
			}

			// Validate event, since it will be used by other domains (i.e.
			// maintain a strong contract).
			err = validate.Struct(event)
			if err != nil {
				panic(err)
			}

			// Skip if no change
			if reflect.DeepEqual(prev, next) {
				return nil
			}

			// Call listeners
			for _, listener := range h.listeners {
				err := listener(event)
				if err != nil {
					return fmt.Errorf(
						"Error calling listener function for external record id %v: %w",
						updatedRecord.Id,
						err,
					)
				}
			}

			return nil
		})
}
