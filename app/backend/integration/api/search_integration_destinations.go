package api

import (
	"log/slog"
	"net/http"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/lib/api"
	integ "exnota.com/backend/lib/integration"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type SearchIntegrationDestinationsAPI interface {
	ApplyHooks()
}

type searchIntegrationDestinationsAPI struct {
	app                          core.App
	integrationDestinationSearch IntegrationDestinationSearch
}

type IntegrationDestinationSearch interface {
	SearchDatabaseDestinations(
		integrationId string,
		userId string,
		query string,
	) (*integ.Destinations, error)
	SearchAllDestinations(
		integrationId string,
		userId string,
		query string,
	) (*integ.Destinations, error)
}

func NewSearchIntegrationDestinationsAPI(
	app core.App,
	integrationDestinationSearch IntegrationDestinationSearch,
) SearchIntegrationDestinationsAPI {
	return &searchIntegrationDestinationsAPI{app, integrationDestinationSearch}
}

type SearchNotionDestinationsRequest struct {
	IntegrationID string                 `json:"integration_id" validate:"min=1"`
	Object        integ.NotionObjectType `json:"object"         validate:"omitempty,oneof=database page"`
	Query         string                 `json:"query"`
}

type SearchIntegrationDestinationsResponse struct {
	Destinations integ.Destinations `json:"destinations"`
}

func (h *searchIntegrationDestinationsAPI) ApplyHooks() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(api.SearchIntegrationDestinations, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.SearchIntegrationDestinations,
			)

			// Parse and validate request
			req := new(SearchNotionDestinationsRequest)
			if err := c.Bind(req); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			err := validate.Struct(req)
			if err != nil {
				return err
			}

			// Auth
			auth := NewIntegrationAuth(h.app, data.NewIntegrationFetcher(h.app), c)
			err = auth.ForIntegration(req.IntegrationID)
			if err != nil {
				return err
			}

			switch req.Object {
			case integ.NotionObjectTypeDatabase:
				result, err := h.integrationDestinationSearch.SearchDatabaseDestinations(
					req.IntegrationID,
					auth.LoggedInUser(),
					req.Query,
				)
				if err != nil {
					return err
				}
				return c.JSON(200, &SearchIntegrationDestinationsResponse{
					Destinations: *result,
				})
			case integ.NotionObjectTypePage, "":
				result, err := h.integrationDestinationSearch.SearchAllDestinations(
					req.IntegrationID,
					auth.LoggedInUser(),
					req.Query,
				)
				if err != nil {
					return err

				}
				return c.JSON(200, &SearchIntegrationDestinationsResponse{
					Destinations: *result,
				})
			default:
				panic("unsupported workspace type")
			}
		})

		return nil
	})
}
