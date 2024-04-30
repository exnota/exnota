package service

import (
	"exnota.com/backend/block/data"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type WorkspaceUpdaterService interface {
	SetConnectedForIntegration(request StatusForIntegrationRequest) error
	SetDisconnectedForIntegration(request StatusForIntegrationRequest) error
}

type workspaceUpdaterService struct {
	app core.App
}

func NewWorkspaceUpdaterService(app core.App) WorkspaceUpdaterService {
	return &workspaceUpdaterService{app}
}

type StatusForIntegrationRequest struct {
	IntegrationId string `validate:"min=1"`
}

func (w *workspaceUpdaterService) SetConnectedForIntegration(request StatusForIntegrationRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	err = w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		workspaceFetcher := data.NewWorkspaceFetcher(w.app, txDao)
		workspaces, err := workspaceFetcher.FetchByIntegrationId(request.IntegrationId)
		if err != nil {
			return err
		}

		for _, workspace := range workspaces {
			err = workspace.SetExternalStatus(data.WorkspaceExternalStatusConnected)
			if err != nil {
				return err
			}

			err = workspace.ValidateAndSubmit(txDao)
			if err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	return nil
}

func (w *workspaceUpdaterService) SetDisconnectedForIntegration(request StatusForIntegrationRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	err = w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		workspaceFetcher := data.NewWorkspaceFetcher(w.app, txDao)
		workspaces, err := workspaceFetcher.FetchByIntegrationId(request.IntegrationId)
		if err != nil {
			return err
		}

		for _, workspace := range workspaces {
			err = workspace.SetExternalStatus(data.WorkspaceExternalStatusDisconnected)
			if err != nil {
				return err
			}

			err = workspace.ValidateAndSubmit(txDao)
			if err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	return nil
}
