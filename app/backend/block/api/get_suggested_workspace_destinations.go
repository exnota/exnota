package api

import (
	"log/slog"
	"net/http"

	"exnota.com/backend/block"
	"exnota.com/backend/lib/api"
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type GetSuggestedWorkspaceDestinationsAPI interface {
	ApplyHooks()
}

type getSuggestedWorkspaceDestinationsAPI struct {
	app                      core.App
	getSuggestedDestinations lib_integ.GetSuggestedIntegrationDestinations
	workspaceFetcher         block.WorkspaceFetcher
}

func NewGetSuggestedWorkspaceDestinationsAPI(
	app core.App,
	getSuggestedIntegrationDestinations lib_integ.GetSuggestedIntegrationDestinations,
	workspaceFetcher block.WorkspaceFetcher,
) GetSuggestedWorkspaceDestinationsAPI {
	return &getSuggestedWorkspaceDestinationsAPI{
		app,
		getSuggestedIntegrationDestinations,
		workspaceFetcher,
	}
}

type GetSuggestedDestinationsRequest struct {
	WorkspaceId string `json:"workspace_id" validate:"min=1"`
}

type GetSuggestedDestinationsResponse struct {
	Destinations lib_integ.Destinations `json:"destinations"`
}

func (h *getSuggestedWorkspaceDestinationsAPI) ApplyHooks() {
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
			syncRequest := new(GetSuggestedDestinationsRequest)
			if err := c.Bind(syncRequest); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}
			err := validate.Struct(syncRequest)
			if err != nil {
				return err
			}

			// Auth
			auth := NewWorkspaceAuth(h.app, h.workspaceFetcher, c)
			err = auth.ForWorkspace(syncRequest.WorkspaceId)
			if err != nil {
				return err
			}

			workspace, err := h.workspaceFetcher.FetchById(syncRequest.WorkspaceId)
			if err != nil {
				return err
			}

			if workspace.Integration() == "" {
				return c.String(http.StatusBadRequest, "workspace has no integration")
			}

			// Update status
			destinations, err := h.getSuggestedDestinations(
				lib_integ.GetSuggestedDestinationsRequest{
					IntegrationID: workspace.Integration(),
					UserID:        auth.LoggedInUser(),
					WorkspaceType: mapWorkspaceType(workspace.Type()),
				},
			)
			if err != nil {
				return c.JSON(http.StatusInternalServerError, nil)
			}

			return c.JSON(http.StatusOK, &GetSuggestedDestinationsResponse{
				Destinations: *destinations,
			})
		})
		return nil
	})
}

func mapWorkspaceType(workspaceType block.WorkspaceType) lib_integ.WorkspaceType {
	switch workspaceType {
	case block.WorkspaceTypeDatabase:
		return lib_integ.WorkspaceTypeDatabase
	case block.WorkspaceTypeCustom:
		return lib_integ.WorkspaceTypeCustom
	default:
		panic("unsupported workspace type")
	}
}
