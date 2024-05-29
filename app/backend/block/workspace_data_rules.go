package block

import (
	"errors"
	"fmt"

	"github.com/pocketbase/pocketbase/core"
)

type WorkspaceDataRules interface {
	ApplyHooks()
}

type workspaceDataRules struct {
	app                core.App
	workspaceFetcher   WorkspaceFetcher
	integrationFetcher IntegrationFetcher
}

type IntegrationFetcher interface {
	UserForIntegration(integrationId string) (*string, error)
}

func NewWorkspaceDataRules(
	app core.App,
	workspaceFetcher WorkspaceFetcher,
	integrationFetcher IntegrationFetcher,
) WorkspaceDataRules {
	return &workspaceDataRules{app, workspaceFetcher, integrationFetcher}
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
			integrationUser, err := r.integrationFetcher.UserForIntegration(workspace.Integration())
			if err != nil {
				return fmt.Errorf(
					"Error fetching user for integration %v : %v",
					workspace.Integration(),
					err,
				)
			}

			if *integrationUser != workspace.User() {
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
