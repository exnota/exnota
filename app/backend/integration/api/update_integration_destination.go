package api

import (
	"log/slog"
	"net/http"
	"strings"

	"exnota.com/backend/integration"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/apis"
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
	IntegrationId string `json:"integration_id"`
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

			// Parse request
			updaterequest := new(UpdateIntegrationDestinationRequest)
			if err := c.Bind(updaterequest); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			if strings.TrimSpace(updaterequest.IntegrationId) == "" {
				return c.JSON(http.StatusBadRequest, nil)
			}

			// Get user
			requestInfo := apis.RequestInfo(c)
			if requestInfo.AuthRecord == nil {
				return c.String(http.StatusUnauthorized, "Not logged in")
			}
			// loggedInUserId := requestInfo.AuthRecord.Id

			// TODO: Verify user matches integration

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
