package api

import (
	"log/slog"
	"net/http"

	"exnota.com/backend/block"
	"exnota.com/backend/lib/api"
	integ "exnota.com/backend/lib/integration"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type SearchWorkspaceDestinationsAPI interface {
	ApplyHooks()
}

type searchWorkspaceDestinationsAPI struct {
	app                          core.App
	workspaceFetcher             block.WorkspaceFetcher
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

func NewSearchWorkspaceDestinationsAPI(
	app core.App,
	workspaceFetcher block.WorkspaceFetcher,
	integrationDestinationSearch IntegrationDestinationSearch,
) SearchWorkspaceDestinationsAPI {
	return &searchWorkspaceDestinationsAPI{app, workspaceFetcher, integrationDestinationSearch}
}

type SearchWorkspaceDestinationsRequest struct {
	WorkspaceID string `json:"workspace_id" validate:"min=1"`
	Query       string `json:"query"`
}

type SearchWorkspaceDestinationsResponse struct {
	Destinations integ.Destinations `json:"destinations"`
}

func (h *searchWorkspaceDestinationsAPI) ApplyHooks() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(api.SearchWorkspaceDestinations, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.SearchWorkspaceDestinations,
			)

			// Parse and validate request
			req := new(SearchWorkspaceDestinationsRequest)
			if err := c.Bind(req); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			err := validate.Struct(req)
			if err != nil {
				return err
			}

			// Auth
			auth := NewWorkspaceAuth(h.app, h.workspaceFetcher, c)
			err = auth.ForWorkspace(req.WorkspaceID)
			if err != nil {
				return err
			}

			workspace, err := h.workspaceFetcher.FetchById(req.WorkspaceID)
			if err != nil {
				return err
			}
			if workspace.Integration() == "" {
				return c.String(http.StatusBadRequest, "workspace has no integration")
			}

			switch workspace.Type() {
			case block.WorkspaceTypeDatabase:
				result, err := h.integrationDestinationSearch.SearchDatabaseDestinations(
					workspace.Integration(),
					auth.LoggedInUser(),
					req.Query,
				)
				if err != nil {
					return err
				}
				return c.JSON(200, &SearchWorkspaceDestinationsResponse{
					Destinations: *result,
				})
			case block.WorkspaceTypeCustom:
				result, err := h.integrationDestinationSearch.SearchAllDestinations(
					workspace.Integration(),
					auth.LoggedInUser(),
					req.Query,
				)
				if err != nil {
					return err

				}
				return c.JSON(200, &SearchWorkspaceDestinationsResponse{
					Destinations: *result,
				})
			default:
				panic("unsupported workspace type")
			}
		})

		return nil
	})
}
