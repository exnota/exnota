package event

import (
	"fmt"

	"exnota.com/backend/block/service"
	integration_data "exnota.com/backend/integration/data"
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
		integration_data.CollectionIntegration).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			newIntegration, err := integration_data.LoadIntegration(record, l.app)
			if err != nil {
				return err
			}

			prevIntegration, err := integration_data.LoadIntegration(record.OriginalCopy(), l.app)
			if err != nil {
				return err
			}

			if prevIntegration.Status() != newIntegration.Status() {
				switch newIntegration.Status() {
				case integration_data.IntegrationStatusConnected:
					workspaceUpdaterService := service.NewWorkspaceUpdaterService(l.app)
					err = workspaceUpdaterService.SetConnectedForIntegration(service.StatusForIntegrationRequest{
						IntegrationId: newIntegration.Id(),
					})

					if err != nil {
						return err
					}
				case integration_data.IntegrationStatusAccessRevoked:
					workspaceUpdaterService := service.NewWorkspaceUpdaterService(l.app)
					err = workspaceUpdaterService.SetDisconnectedForIntegration(service.StatusForIntegrationRequest{
						IntegrationId: newIntegration.Id(),
					})
					if err != nil {
						return err
					}
				default:
					return fmt.Errorf("Unknown integration status: %s", newIntegration.Status())
				}

			}

			return nil
		},
	)
}
