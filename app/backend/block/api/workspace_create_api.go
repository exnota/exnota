package api

import (
	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type WorkspaceCreateAPI interface {
	ApplyHooks()
}

type workspaceCreateAPI struct {
	app              core.App
	workspaceFetcher block.WorkspaceFetcher
}

func NewWorkspaceCreateAPI(
	app core.App,
	workspaceFetcher block.WorkspaceFetcher,
) WorkspaceCreateAPI {
	return &workspaceCreateAPI{app, workspaceFetcher}
}

func (r *workspaceCreateAPI) ApplyHooks() {
	r.app.OnRecordBeforeCreateRequest(block.CollectionWorkspace).
		Add(func(e *core.RecordCreateEvent) error {
			newWorkspace, err := block.LoadWorkspace(e.Record, r.app)
			if err != nil {
				return err
			}

			newExternal, err := newWorkspace.External()
			if err != nil {
				return err
			}
			if newExternal != nil {
				return apis.NewBadRequestError("Cannot set external on workspace create", nil)
			}

			if !newWorkspace.Archived().IsZero() {
				return apis.NewBadRequestError("Cannot create archived workspace", nil)
			}

			// Only one non-archived workspace allowed for now
			workspaces, err := r.workspaceFetcher.ListUnarchived(newWorkspace.User())
			if err != nil {
				return err
			}
			if len(workspaces) > 0 {
				return apis.NewBadRequestError("Cannot create multiple unarchived workspaces", nil)
			}

			return nil
		})
}
