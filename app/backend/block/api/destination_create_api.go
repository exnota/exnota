package api

import (
	"fmt"

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
	app                        core.App
	syncIntegratedDestinations SyncIntegratedDestinations
	workspaceFetcher           block.WorkspaceFetcher
	destinationFetcher         block.DestinationFetcher
}

type CreateDestinationSync func(request lib_block.CreateDestinationSyncRequest) (result *lib_block.CreateDestinationSyncResult, err error)

type SyncIntegratedDestinations interface {
	CreateSync(
		request lib_block.CreateDestinationSyncRequest,
	) (result *lib_block.CreateDestinationSyncResult, err error)
	// Returns destination IDs that are integrated with the given integration
	// ID and external config.
	GetDestinationForExternal(
		request lib_block.GetDestinationForExternalRequest,
	) ([]string, error)
}

type GetDestinationForExternalRequest struct {
	IntegrationId string                 `validate:"min=1"`
	UserId        string                 `validate:"min=1"`
	Config        map[string]interface{} `validate:"required"`
}

func NewDestinationCreateAPI(
	app core.App,
	syncDestinationDestination SyncIntegratedDestinations,
	workspaceFetcher block.WorkspaceFetcher,
	destinationFetcher block.DestinationFetcher,
) DestinationCreateAPI {
	return &destinationCreateAPI{
		app,
		syncDestinationDestination,
		workspaceFetcher,
		destinationFetcher,
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

			destination, err := block.LoadDestination(e.Record, h.app)
			if err != nil {
				return err
			}

			// Get integration ID from workspace
			workspace, err := h.workspaceFetcher.FetchById(destination.Workspace())
			if err != nil {
				return err
			}

			// Cannot create as archived
			if !destination.Archived().IsZero() {
				return apis.NewBadRequestError("Cannot create destination as archived", nil)
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
			external, err := destination.External()
			if err != nil {
				return err
			}
			if external == nil {
				return apis.NewBadRequestError("Destination external is nil", nil)
			}

			// Ensure external resource not already integrated with a
			// destination.
			integratedDestinationIDs, err := h.syncIntegratedDestinations.GetDestinationForExternal(
				lib_block.GetDestinationForExternalRequest{
					IntegrationId: integration,
					UserId:        destination.User(),
					Config:        external.Config,
				},
			)
			if err != nil {
				return fmt.Errorf("get destination for external error: %w", err)
			}
			for _, id := range integratedDestinationIDs {
				integratedDestination, err := h.destinationFetcher.FetchById(id)
				if err != nil {
					return fmt.Errorf("fetch integrated destination error: %w", err)
				}
				if integratedDestination.Archived().IsZero() {
					return apis.NewBadRequestError(
						"External resource is already integrated with a destination",
						nil,
					)
				}
			}

			// Sync data from remote resource
			syncResult, err := h.syncIntegratedDestinations.CreateSync(
				lib_block.CreateDestinationSyncRequest{
					DestinationId: destinationID,
					IntegrationId: integration,
					Config:        external.Config,
					User:          destination.User(),
				},
			)
			if err != nil {
				return err
			}
			err = destination.SetExternalNotionStatus(syncResult.NotionStatus)
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
