package api

import (
	"exnota.com/backend/block/data"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type WorkspaceCreateApi interface {
	ApplyHooks()
}

type workspaceCreateApi struct {
	app core.App
}

func NewWorkspaceCreateApi(app core.App) WorkspaceCreateApi {
	return &workspaceCreateApi{app}
}

func (r *workspaceCreateApi) ApplyHooks() {
	r.createRules()
}

func (r *workspaceCreateApi) createRules() {
	r.app.OnRecordBeforeCreateRequest(data.CollectionWorkspace).
		Add(func(e *core.RecordCreateEvent) error {
			newWorkspace, err := data.LoadWorkspace(e.Record, r.app)
			if err != nil {
				return err
			}

			if newWorkspace.Record().GetString(data.WorkspaceFieldExternal) != "" {
				return apis.NewBadRequestError("Cannot change external on workspace update", nil)
			}

			if !newWorkspace.Archived().IsZero() {
				return apis.NewBadRequestError("Cannot create archived workspace", nil)
			}

			// Only one non-archived workspace allowed for now
			fetcher := data.NewWorkspaceFetcher(r.app, r.app.Dao())
			workspaces, err := fetcher.ListUnarchived(newWorkspace.User())
			if err != nil {
				return err
			}
			if len(workspaces) > 0 {
				return apis.NewBadRequestError("Cannot create multiple unarchived workspaces", nil)
			}

			return nil
		})
}
