package integration

import (
	"log/slog"

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

	// TODO: Don't return errors as they will block other 'after update' hook

	// Notion
	h.app.OnModelAfterUpdate(
		CollectionIntegrationNotionObject).Add(
		func(e *core.ModelEvent) error {
			updatedRecord := e.Model.(*models.Record)
			prevObject := LoadIntegrationNotionObject(updatedRecord.OriginalCopy(), h.app)
			nextObject := LoadIntegrationNotionObject(updatedRecord, h.app)

			prev := lib_integ.IntegrationDestinationState{
				NotionObjectStatus: prevObject.Status(),
			}
			next := lib_integ.IntegrationDestinationState{
				NotionObjectStatus: nextObject.Status(),
			}

			// switch prevObject.Type() {
			// case IntegrationNotionObjectTypeDatabase:
			// 	// TODO: Can kinda copy integration/usecase/notion/sync_notion_destination.go
			// case IntegrationNotionObjectTypePage:
			// 	// TODO: Can kinda copy integration/usecase/notion/sync_notion_destination.go
			// default:
			// 	slog.Error("Unknown notion object type", "type", prevObject.Type())
			// }

			// TODO: Validate event and panic if missing something? As a contract?
			// TODO: Don't call listeners if nothing changed
			for _, listener := range h.listeners {
				err := listener(lib_integ.IntegrationDestinationEvent{
					Prev: prev,
					Next: next,
				})
				if err != nil {
					// Don't return error as that will block other 'after update' hooks
					slog.Error("Error calling listener function", "error", err)
				}
			}

			return nil
		})
}
