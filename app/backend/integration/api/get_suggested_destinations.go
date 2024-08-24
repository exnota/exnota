package api

import (
	"log/slog"
	"net/http"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/lib/api"
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type GetSuggestedDestinationsAPI interface {
	ApplyHooks()
}

type getSuggestedDestinationsAPI struct {
	app                      core.App
	getSuggestedDestinations lib_integ.GetSuggestedIntegrationDestinations
}

func NewGetSuggestedDestinationsAPI(
	app core.App,
	getSuggestedIntegrationDestinations lib_integ.GetSuggestedIntegrationDestinations,
) GetSuggestedDestinationsAPI {
	return &getSuggestedDestinationsAPI{
		app,
		getSuggestedIntegrationDestinations,
	}
}

type GetSuggestedDestinationsRequest struct {
	IntegrationId string `json:"integration_id" validate:"min=1"`
}

type GetSuggestedDestinationsResponse struct {
	Destinations lib_integ.Destinations `json:"destinations"`
}

func (h *getSuggestedDestinationsAPI) ApplyHooks() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(api.GetSuggestedDestinations, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.GetSuggestedDestinations,
			)

			// Parse and validate request
			request := new(GetSuggestedDestinationsRequest)
			if err := c.Bind(request); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			err := validate.Struct(request)
			if err != nil {
				return err
			}

			// Auth
			auth := NewIntegrationAuth(h.app, data.NewIntegrationFetcher(h.app), c)
			err = auth.ForIntegration(request.IntegrationId)
			if err != nil {
				return err
			}

			// Update status
			destinations, err := h.getSuggestedDestinations(
				lib_integ.GetSuggestedDestinationsRequest{
					IntegrationID: request.IntegrationId,
					UserID:        auth.LoggedInUser(),
				},
			)
			if err != nil {
				return err
			}

			return c.JSON(http.StatusOK, &GetSuggestedDestinationsResponse{
				Destinations: *destinations,
			})
		})
		return nil
	})
}
