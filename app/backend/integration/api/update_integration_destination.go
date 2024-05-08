package api

import (
	"log/slog"
	"net/http"

	"exnota.com/backend/integration"
	"exnota.com/backend/integration/data"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type UpdateIntegrationDestinationAPI interface {
	ApplyHooks()
}

type updateIntegrationDestinationAPI struct {
	app core.App
}

func NewUpdateIntegrationDestinationAPI(
	app core.App,
) UpdateIntegrationDestinationAPI {
	return &updateIntegrationDestinationAPI{app: app}
}

type UpdateIntegrationDestinationRequest struct {
	IntegrationId string `json:"integration_id" validate:"min=1"`
}

func (h *updateIntegrationDestinationAPI) ApplyHooks() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.POST(integration.IntegrationUpdateDestination, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				integration.IntegrationUpdateDestination,
			)

			// Parse and validate request
			updateRequest := new(UpdateIntegrationDestinationRequest)
			if err := c.Bind(updateRequest); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			err := validate.Struct(updateRequest)
			if err != nil {
				return err
			}

			// Auth
			auth := NewIntegrationAuth(h.app, data.NewIntegrationFetcher(h.app))
			err = auth.ForIntegration(updateRequest.IntegrationId, c)
			if err != nil {
				return err
			}

			// Update status
			// integrationSync := service.NewIntegrationSync(h.app)
			// err := integrationSync.UpdateDestinationStatus(service.UpdateDestinationStatusRequest{
			// 	IntegrationId: updaterequest.IntegrationId,
			// 	UserID:        loggedInUserId,
			// })
			// if err != nil {
			// 	return c.JSON(http.StatusInternalServerError, nil)
			// }

			return nil
		})
		return nil
	})
}
