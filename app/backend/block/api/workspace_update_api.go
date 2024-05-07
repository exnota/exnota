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
	app              core.App
	workspaceFetcher block.WorkspaceFetcher
}

func NewWorkspaceUpdateAPI(
	app core.App,
	workspaceFetcher block.WorkspaceFetcher,
) WorkspaceUpdateAPI {
	return &workspaceUpdateAPI{app, workspaceFetcher}
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

			return nil
		})
}
