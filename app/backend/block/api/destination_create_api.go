package api

import (
	"exnota.com/backend/block"
	lib_block "exnota.com/backend/lib/block"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
)

type DestinationCreateAPI interface {
	ApplyHooks()
}

type destinationCreateAPI struct {
	app              core.App
	destinationSync  DestinationSync
	workspaceFetcher block.WorkspaceFetcher
}

type DestinationSync func(request lib_block.DestinationSyncRequest) (result *lib_block.DestinationSyncResult, err error)

func NewDestinationCreateAPI(
	app core.App,
	destinationSync DestinationSync,
	workspaceFetcher block.WorkspaceFetcher,
) DestinationCreateAPI {
	return &destinationCreateAPI{
		app:              app,
		destinationSync:  destinationSync,
		workspaceFetcher: workspaceFetcher,
	}
}

func (h *destinationCreateAPI) ApplyHooks() {
	h.app.OnRecordBeforeCreateRequest(block.CollectionDestination).
		Add(func(e *core.RecordCreateEvent) error {
			// Validate early to avoid extra work if there's a simple validation
			// error
			form := forms.NewRecordUpsert(h.app, e.Record)
			err := form.Validate()
			if err != nil {
				return err
			}

			destination, err := block.NewDestination(e.Record, h.app)
			if err != nil {
				return err
			}

			// Get integration ID from workspace
			workspace, err := h.workspaceFetcher.FetchById(destination.Workspace())
			if err != nil {
				return err
			}

			// If there's no integration, skip syncing the destination
			integration := workspace.Integration()
			if integration == "" {
				return nil
			}

			// Validate: ID set client-side, external field set
			destinationID := destination.Id()
			if destinationID == "" {
				return apis.NewBadRequestError("Destination ID is empty", nil)
			}
			external := destination.External()
			if external == nil {
				return apis.NewBadRequestError("Destination external is nil", nil)
			}

			// Sync data from remote destination
			syncResult, err := h.destinationSync(lib_block.DestinationSyncRequest{
				DestinationId: destinationID,
				IntegrationId: integration,
				Config:        external.Config,
				User:          destination.User(),
			})
			if err != nil {
				return err
			}

			// Update destination using data from sync
			destination.SetName(syncResult.DestinationName)
			err = destination.Validate()
			if err != nil {
				return err
			}

			return nil
		})
}
