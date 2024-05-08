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
	app                   core.App
	createDestinationSync CreateDestinationSync
	workspaceFetcher      block.WorkspaceFetcher
}

type CreateDestinationSync func(request lib_block.CreateDestinationSyncRequest) (result *lib_block.CreateDestinationSyncResult, err error)

func NewDestinationCreateAPI(
	app core.App,
	createDestinationSync CreateDestinationSync,
	workspaceFetcher block.WorkspaceFetcher,
) DestinationCreateAPI {
	return &destinationCreateAPI{
		app:                   app,
		createDestinationSync: createDestinationSync,
		workspaceFetcher:      workspaceFetcher,
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
			syncResult, err := h.createDestinationSync(lib_block.CreateDestinationSyncRequest{
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
