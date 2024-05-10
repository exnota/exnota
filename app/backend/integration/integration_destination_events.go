package integration

import (
	"log/slog"
	"reflect"

	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationDestinationEvents interface {
	ApplyHooks()
}

type integrationDestinationEvents struct {
	app       core.App
	listeners []lib_integ.IntegrationDestinationEventListener
}

func NewIntegrationDestinationEvents(
	app core.App,
	listeners []lib_integ.IntegrationDestinationEventListener,
) IntegrationDestinationEvents {
	return &integrationDestinationEvents{app, listeners}
}

func (h *integrationDestinationEvents) ApplyHooks() {
	// Notion
	h.app.OnModelAfterUpdate(
		CollectionIntegrationNotionObject).Add(
		func(e *core.ModelEvent) error {
			updatedRecord := e.Model.(*models.Record)
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
				Prev: prev,
				Next: next,
			}
			err := validate.Struct(event)
			if err != nil {
				return err
			}

			if reflect.DeepEqual(prev, next) {
				return nil
			}

			for _, listener := range h.listeners {
				err := listener(event)
				if err != nil {
					// Don't return error as that will block other 'after update' hooks
					slog.Error("Error calling listener function", "error", err)
					continue
				}
			}

			return nil
		})
}
