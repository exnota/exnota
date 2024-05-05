package api

import (
	"reflect"

	"exnota.com/backend/block/data"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type WorkspaceUpdateApi interface {
	ApplyHooks()
}

type workspaceUpdateApi struct {
	app core.App
}

func NewWorkspaceUpdateApi(app core.App) WorkspaceUpdateApi {
	return &workspaceUpdateApi{app}
}

func (r *workspaceUpdateApi) ApplyHooks() {
	r.updateRules()
}

func (r *workspaceUpdateApi) updateRules() {
	r.app.OnRecordBeforeUpdateRequest(data.CollectionWorkspace).
		Add(func(e *core.RecordUpdateEvent) error {
			updatedWorkspace, err := data.LoadWorkspace(e.Record, r.app)
			if err != nil {
				return err
			}
			updatedExternal, err := updatedWorkspace.External()
			if err != nil {
				return err
			}

			fetcher := data.NewWorkspaceFetcher(r.app, r.app.Dao())
			existingWorkspace, err := fetcher.FetchById(updatedWorkspace.Id())
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
				fetcher := data.NewWorkspaceFetcher(r.app, r.app.Dao())
				workspaces, err := fetcher.ListUnarchived(updatedWorkspace.User())
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
