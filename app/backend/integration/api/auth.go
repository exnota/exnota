package api

import (
	"cmp"
	"fmt"
	"net/http"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/lib/api"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationAuth interface {
	api.AuthBase

	// Returns an error if the logged in user user does not have access to the
	// integration.
	ForIntegration(integrationId string) error
}

type integrationAuth struct {
	api.Base
	integrationFetcher integ.IntegrationFetcher
}

func NewIntegrationAuth(
	app core.App,
	integrationFetcher integ.IntegrationFetcher,
	context echo.Context,
) IntegrationAuth {
	return &integrationAuth{
		Base: api.Base{
			App:     app,
			Context: context,
		},
		integrationFetcher: integrationFetcher,
	}
}

func (h *integrationAuth) ForIntegration(integrationId string) error {
	// Get user
	loggedInUserId := h.LoggedInUser()
	if loggedInUserId == "" {
		cErr := h.Context.String(http.StatusUnauthorized, "Not logged in")
		return cmp.Or(cErr, fmt.Errorf("Not logged in"))
	}

	// Get integration
	_, err := h.integrationFetcher.FetchById(integ.FetchByIdRequest{
		IntegrationId: integrationId,
		UserId:        loggedInUserId,
	})
	if err != nil {
		// The integration may not exist or may not belong to the user. But
		// probably not worth separating those cases, so just return forbidden.
		cErr := h.Context.String(http.StatusForbidden, "Forbidden")
		return cmp.Or(cErr, err)
	}

	return nil
}
