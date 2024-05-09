package event

import (
	"exnota.com/backend/block/data"
	"exnota.com/backend/block/service"
	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationListener interface {
	// Applies hooks that listen to integration events and call services in
	// other domains.
	ApplyHooks()
}

type integrationListener struct {
	app core.App
}

func NewIntegrationListener(app core.App) IntegrationListener {
	return &integrationListener{
		app: app,
	}
}

func (l *integrationListener) ApplyHooks() {
	l.applyOnUpdateHooks()
}

func (l *integrationListener) applyOnUpdateHooks() {
	l.app.OnModelAfterUpdate(
		integ.CollectionIntegration).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			newIntegration, err := integ.LoadIntegration(record, l.app)
			if err != nil {
				return err
			}

			prevIntegration, err := integ.LoadIntegration(record.OriginalCopy(), l.app)
			if err != nil {
				return err
			}

			archived := prevIntegration.Archived().IsZero() && !newIntegration.Archived().IsZero()
			unarchived := !prevIntegration.Archived().IsZero() && newIntegration.Archived().IsZero()
			if newIntegration.Status() == integ.IntegrationStatusConnected {
				// If status changed to connected, or if the integration was
				// unarchived while having a connected status.
				// Then set workspaces to connected.
				if prevIntegration.Status() != integ.IntegrationStatusConnected ||
					unarchived {
					// Status changed to connected - cascade to workspaces
					workspaceUpdaterService := service.NewWorkspaceUpdaterService(
						l.app,
						data.NewWorkspaceFetcher(l.app),
					)
					err = workspaceUpdaterService.SetConnectedForIntegration(
						service.StatusForIntegrationRequest{
							IntegrationId: newIntegration.Id(),
						},
					)
					if err != nil {
						return err
					}
				}
			} else if newIntegration.Status() == integ.IntegrationStatusAccessRevoked {
				// If status changed to access-revoked, or if the integration
				// was unarchived while having an access-revoked status.
				// Then set workspaces to disconnected.
				if prevIntegration.Status() != integ.IntegrationStatusAccessRevoked ||
					unarchived {
					// Status changed to access-revoked - cascade to workspaces
					workspaceUpdaterService := service.NewWorkspaceUpdaterService(l.app, data.NewWorkspaceFetcher(l.app))
					err = workspaceUpdaterService.SetDisconnectedForIntegration(
						service.StatusForIntegrationRequest{
							IntegrationId: newIntegration.Id(),
						},
					)
					if err != nil {
						return err
					}
				}
			}
			if archived {
				// If the integration was archived, then set workspaces to
				// archived.
				workspaceUpdaterService := service.NewWorkspaceUpdaterService(
					l.app,
					data.NewWorkspaceFetcher(l.app),
				)
				err = workspaceUpdaterService.SetArchivedForIntegration(
					service.StatusForIntegrationRequest{
						IntegrationId: newIntegration.Id(),
					},
				)
				if err != nil {
					return err
				}
			}

			return nil
		},
	)
}
