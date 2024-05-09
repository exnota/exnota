package event_listeners

import (
	"log/slog"

	"exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type DestinationIntegrationUpdate interface {
	Update(event integration.IntegrationDestinationEvent) error
}

type destinationIntegrationUpdate struct {
	app core.App
}

func NewDestinationIntegrationUpdate(
	app core.App,
) DestinationIntegrationUpdate {
	return &destinationIntegrationUpdate{
		app,
	}
}

func (h *destinationIntegrationUpdate) Update(event integration.IntegrationDestinationEvent) error {
	slog.Info(
		"DestinationIntegrationUpdate.Update",
		"event.prev.status",
		event.Prev.NotionStatus,
		"event.next.status",
		event.Next.NotionStatus,
	)
	return nil
}
