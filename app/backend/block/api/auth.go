package api

import (
	"cmp"
	"fmt"
	"net/http"

	"exnota.com/backend/block"
	"exnota.com/backend/lib/api"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type BlockAuth interface {
	api.AuthBase

	// Returns an error if the logged in user user does not have access to the
	// workspace.
	ForWorkspace(workspaceId string) error
}

type workspaceAuth struct {
	api.Base
	workspaceFetcher block.WorkspaceFetcher
}

func NewWorkspaceAuth(
	app core.App,
	workspaceFetcher block.WorkspaceFetcher,
	context echo.Context,
) BlockAuth {
	return &workspaceAuth{
		Base: api.Base{
			App:     app,
			Context: context,
		},
		workspaceFetcher: workspaceFetcher,
	}
}

func (h *workspaceAuth) ForWorkspace(workspaceId string) error {
	// Get user
	loggedInUserId := h.LoggedInUser()
	if loggedInUserId == "" {
		cErr := h.Context.String(http.StatusUnauthorized, "Not logged in")
		return cmp.Or(cErr, fmt.Errorf("Not logged in"))
	}

	// Get workspace
	workspace, err := h.workspaceFetcher.FetchById(workspaceId)
	if err != nil {
		return fmt.Errorf("failed to fetch workspace %v: %w", workspaceId, err)
	}

	if workspace.User() != loggedInUserId {
		cErr := h.Context.String(http.StatusForbidden, "Forbidden")
		return cmp.Or(
			cErr,
			fmt.Errorf("User %v does not have access to workspace %v", loggedInUserId, workspaceId),
		)
	}

	return nil
}
