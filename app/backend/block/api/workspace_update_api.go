package api

import (
	"reflect"

	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type WorkspaceUpdateAPI interface {
	ApplyHooks()
}

type workspaceUpdateAPI struct {
	app                core.App
	workspaceFetcher   block.WorkspaceFetcher
	destinationFetcher block.DestinationFetcher
}

func NewWorkspaceUpdateAPI(
	app core.App,
	workspaceFetcher block.WorkspaceFetcher,
	destinationFetcher block.DestinationFetcher,
) WorkspaceUpdateAPI {
	return &workspaceUpdateAPI{app, workspaceFetcher, destinationFetcher}
}

func (r *workspaceUpdateAPI) ApplyHooks() {
	r.app.OnRecordBeforeUpdateRequest(block.CollectionWorkspace).
		Add(func(e *core.RecordUpdateEvent) error {
			updatedWorkspace, err := block.LoadWorkspace(e.Record, r.app)
			if err != nil {
				return err
			}
			updatedExternal, err := updatedWorkspace.External()
			if err != nil {
				return err
			}

			existingWorkspace, err := r.workspaceFetcher.FetchById(updatedWorkspace.Id())
			if err != nil {
				return err
			}
			existingExternal, err := existingWorkspace.External()
			if err != nil {
				return err
			}

			// Can't change external from API
			externalChanged := !reflect.DeepEqual(updatedExternal, existingExternal)
			if externalChanged {
				return apis.NewBadRequestError(
					"Cannot change external on workspace update",
					nil,
				)
			}

			// When unarchiving, check for existing unarchived workspaces.
			//
			// Only one non-archived workspace allowed for now
			if !existingWorkspace.Archived().IsZero() && updatedWorkspace.Archived().IsZero() {
				workspaces, err := r.workspaceFetcher.ListUnarchived(updatedWorkspace.User())
				if err != nil {
					return err
				}
				if len(workspaces) > 0 {
					return apis.NewBadRequestError(
						"Cannot have multiple unarchived workspaces",
						nil,
					)
				}
			}

			// When archiving, error if there are non-archived destinations
			if existingWorkspace.Archived().IsZero() && !updatedWorkspace.Archived().IsZero() {
				destinations, err := r.destinationFetcher.ListByWorkspace(updatedWorkspace.Id())
				if err != nil {
					return err
				}
				if len(destinations) > 0 {
					return apis.NewBadRequestError(
						"Cannot archive workspace with unarchived destinations",
						nil,
					)
				}
			}

			return nil
		})
}
