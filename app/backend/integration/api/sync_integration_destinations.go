package api

import (
	"log/slog"
	"net/http"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase"
	"exnota.com/backend/lib/api"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type SyncIntegrationDestinationsAPI interface {
	ApplyHooks()
}

type syncIntegrationDestinationsAPI struct {
	app                        core.App
	integrationDestinationSync usecase.IntegrationDestinationSync
}

func NewSyncIntegrationDestinationsAPI(
	app core.App,
	integrationDestinationSync usecase.IntegrationDestinationSync,
) SyncIntegrationDestinationsAPI {
	return &syncIntegrationDestinationsAPI{app, integrationDestinationSync}
}

type SyncIntegrationDestinationsRequest struct {
	IntegrationId string `json:"integration_id" validate:"min=1"`
}

func (h *syncIntegrationDestinationsAPI) ApplyHooks() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.POST(api.SyncIntegrationDestinations, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.SyncIntegrationDestinations,
			)

			// Parse and validate request
			syncRequest := new(SyncIntegrationDestinationsRequest)
			if err := c.Bind(syncRequest); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			err := validate.Struct(syncRequest)
			if err != nil {
				return err
			}

			// Auth
			auth := NewIntegrationAuth(h.app, data.NewIntegrationFetcher(h.app), c)
			err = auth.ForIntegration(syncRequest.IntegrationId)
			if err != nil {
				return err
			}

			// Update status
			err = h.integrationDestinationSync.UpdateSync(usecase.UpdateSyncRequest{
				IntegrationId: syncRequest.IntegrationId,
				UserId:        auth.LoggedInUser(),
			})
			if err != nil {
				slog.Error(
					"Failed to update integration destination sync",
					"error",
					err,
				)
				return err
			}

			return nil
		})
		return nil
	})
}
