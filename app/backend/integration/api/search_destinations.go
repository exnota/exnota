package api

import (
	"log/slog"
	"net/http"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/usecase"
	uc_notion "exnota.com/backend/integration/usecase/notion"
	"exnota.com/backend/lib/api"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type SearchDestinationsAPI interface {
	ApplyHooks()
}

type searchDestinationsAPI struct {
	app                core.App
	integrationFetcher integ.IntegrationFetcher
	searchDestinations usecase.SearchDestinations
}

func NewSearchDestinationsAPI(
	app core.App,
	integrationFetcher integ.IntegrationFetcher,
	searchDestinations usecase.SearchDestinations,
) SearchDestinationsAPI {
	return &searchDestinationsAPI{app, integrationFetcher, searchDestinations}
}

type SearchDestinationsRequest struct {
	IntegrationID string                        `json:"integration_id" validate:"min=1"`
	Query         string                        `json:"query"`
	Notion        *uc_notion.NotionSearchParams `json:"notion"`
}

func (h *searchDestinationsAPI) ApplyHooks() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(api.SearchDestinationsPath, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.SearchDestinationsPath,
			)

			// Parse and validate request
			req := new(SearchDestinationsRequest)
			if err := c.Bind(req); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			err := validate.Struct(req)
			if err != nil {
				return err
			}

			// Auth
			auth := NewIntegrationAuth(h.app, h.integrationFetcher, c)
			err = auth.ForIntegration(req.IntegrationID)
			if err != nil {
				return err
			}

			result, err := h.searchDestinations.Search(usecase.SearchDestinationsRequest{
				IntegrationID: req.IntegrationID,
				UserID:        auth.LoggedInUser(),
				Query:         req.Query,
				Notion:        req.Notion,
			})
			if err != nil {
				return err
			}

			return c.JSON(200, result)
		})
		return nil
	})
}
