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
				NotionStatus: h.toEventStatus(prevObject.Status()),
			}
			next := lib_integ.IntegrationDestinationState{
				NotionStatus: h.toEventStatus(nextObject.Status()),
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

func (h *integrationDestinationEvents) toEventStatus(
	status IntegrationNotionObjectStatus,
) lib_integ.IntegrationDestinationNotionStatus {
	switch status {
	case IntegrationNotionObjectStatusConnected:
		return lib_integ.IntegrationDestinationNotionStatusConnected
	case IntegrationNotionObjectStatusNotFound:
		return lib_integ.IntegrationDestinationNotionStatusNotFound
	case IntegrationNotionObjectStatusArchived:
		return lib_integ.IntegrationDestinationNotionStatusArchived
	case IntegrationNotionObjectStatusUnknownError:
		return lib_integ.IntegrationDestinationNotionStatusError
	case IntegrationNotionObjectStatusRateLimited:
		return lib_integ.IntegrationDestinationNotionStatusError
	default:
		panic("Unknown notion object status: " + status)
	}
}
