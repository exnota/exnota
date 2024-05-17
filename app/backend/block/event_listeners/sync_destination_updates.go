package event_listeners

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/block"
	"exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type SyncDestinationUpdates interface {
	Update(event integration.IntegrationDestinationEvent) error
}

type syncDestinationUpdates struct {
	app                core.App
	destinationWriter  block.DestinationWriter
	destinationFetcher block.DestinationFetcher
}

func NewSyncDestinationUpdates(
	app core.App,
	destinationWriter block.DestinationWriter,
	destinationFetcher block.DestinationFetcher,
) SyncDestinationUpdates {
	return &syncDestinationUpdates{
		app,
		destinationWriter,
		destinationFetcher,
	}
}

// Called when a destination in the Integration Notion Object collection is
// updated.
func (h *syncDestinationUpdates) Update(event integration.IntegrationDestinationEvent) error {
	slog.Info(
		"SyncDestinationUpdates.Update",
		"destinationId",
		event.Id,
	)

	// Ignore if destination archived
	destination, err := h.destinationFetcher.FetchById(event.Id)
	if err != nil {
		return fmt.Errorf("failed to fetch destination %v: %w", event.Id, err)
	}
	if !destination.Archived().IsZero() {
		return nil
	}

	err = h.destinationWriter.Update(block.DestinationUpdateRequest{
		Id:           event.Id,
		Name:         event.Next.Name,
		NotionStatus: event.Next.NotionObjectStatus,
	})
	if err != nil {
		return fmt.Errorf("failed to update destination %v: %w", event.Id, err)
	}

	return nil
}
