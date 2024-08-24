package service

import (
	"time"

	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type WorkspaceUpdaterService interface {
	SetConnectedForIntegration(request StatusForIntegrationRequest) error
	SetDisconnectedForIntegration(request StatusForIntegrationRequest) error
	SetArchivedForIntegration(request StatusForIntegrationRequest) error
}

type workspaceUpdaterService struct {
	app              core.App
	workspaceFetcher block.WorkspaceFetcher
}

func NewWorkspaceUpdaterService(
	app core.App,
	workspaceFetcher block.WorkspaceFetcher,
) WorkspaceUpdaterService {
	return &workspaceUpdaterService{app, workspaceFetcher}
}

type StatusForIntegrationRequest struct {
	IntegrationId string `validate:"min=1"`
}

func (w *workspaceUpdaterService) SetConnectedForIntegration(
	request StatusForIntegrationRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	err = w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		workspaces, err := w.workspaceFetcher.FetchByIntegrationIdInTx(request.IntegrationId, txDao)
		if err != nil {
			return err
		}

		for _, workspace := range workspaces {
			err = workspace.SetExternalStatus(block.WorkspaceExternalStatusConnected)
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

func (w *workspaceUpdaterService) SetDisconnectedForIntegration(
	request StatusForIntegrationRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	err = w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		workspaces, err := w.workspaceFetcher.FetchByIntegrationIdInTx(request.IntegrationId, txDao)
		if err != nil {
			return err
		}

		for _, workspace := range workspaces {
			err = workspace.SetExternalStatus(block.WorkspaceExternalStatusDisconnected)
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

func (w *workspaceUpdaterService) SetArchivedForIntegration(
	request StatusForIntegrationRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	err = w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		workspaces, err := w.workspaceFetcher.FetchByIntegrationIdInTx(request.IntegrationId, txDao)
		if err != nil {
			return err
		}

		now := time.Now()
		for _, workspace := range workspaces {
			workspace.SetArchived(now)
			err = workspace.SetExternalStatus(block.WorkspaceExternalStatusArchived)
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
