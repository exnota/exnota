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
		"❤️ DestinationIntegrationUpdate.Update",
		"event.prev.name",
		event.Prev.Name,
		"event.next.name",
		event.Next.Name,
		"event.prev.status",
		event.Prev.NotionObjectStatus,
		"event.next.status",
		event.Next.NotionObjectStatus,
	)
	return nil
}
