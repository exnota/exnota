package event_listeners

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/block"
	"exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type DestinationIntegrationUpdate interface {
	Update(event integration.IntegrationDestinationEvent) error
}

type destinationIntegrationUpdate struct {
	app               core.App
	destinationWriter block.DestinationWriter
}

func NewDestinationIntegrationUpdate(
	app core.App,
	destinationWriter block.DestinationWriter,
) DestinationIntegrationUpdate {
	return &destinationIntegrationUpdate{
		app,
		destinationWriter,
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
	err := h.destinationWriter.Update(block.DestinationUpdateRequest{
		Id:   event.Id,
		Name: event.Next.Name,
		// TODO: Add status
	})
	if err != nil {
		return fmt.Errorf("failed to update destination %v: %w", event.Id, err)
	}

	return nil
}
