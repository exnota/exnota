package block

import (
	"errors"

	integ_data "exnota.com/backend/integration/data"
	"github.com/pocketbase/pocketbase/core"
)

type WorkspaceDataRules interface {
	ApplyHooks()
}

type workspaceDataRules struct {
	app              core.App
	workspaceFetcher WorkspaceFetcher
}

func NewWorkspaceDataRules(app core.App, workspaceFetcher WorkspaceFetcher) WorkspaceDataRules {
	return &workspaceDataRules{app, workspaceFetcher}
}

func (r *workspaceDataRules) ApplyHooks() {
	r.relationRules()
	r.immutableRules()
}

func (r *workspaceDataRules) relationRules() {
	r.app.OnModelBeforeCreate(CollectionWorkspace).Add(func(e *core.ModelEvent) error {
		workspace, err := LoadWorkspace(e.Model, r.app)
		if err != nil {
			return err
		}

		if workspace.Integration() != "" {
			fetcher := integ_data.NewIntegrationFetcher(r.app)
			integration, err := fetcher.FetchById(workspace.Integration(), workspace.User())
			if err != nil {
				return err
			}
			if integration == nil {
				return errors.New("Integration not found with id: " + workspace.Integration())
			}

			if integration.User() != workspace.User() {
				return errors.New("Integration user does not match workspace user")
			}
		}

		return nil
	})
}

func (r *workspaceDataRules) immutableRules() {
	r.app.OnModelBeforeUpdate(CollectionWorkspace).Add(func(e *core.ModelEvent) error {
		updated, err := LoadWorkspace(e.Model, r.app)
		if err != nil {
			return err
		}

		existing, err := r.workspaceFetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}

		if existing.Type() != updated.Type() {
			return errors.New("Cannot change workspace type")
		}
		if existing.Integration() != updated.Integration() && existing.Integration() != "" {
			return errors.New("Cannot change workspace integration")
		}
		if existing.User() != updated.User() {
			return errors.New("Cannot change workspace user")
		}

		return nil
	})
}
