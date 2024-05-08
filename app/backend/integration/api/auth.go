package api

import (
	"net/http"

	"exnota.com/backend/integration/data"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationAuth interface {
	// Returns an error if the logged in user user does not have access to the
	// integration.
	ForIntegration(integrationId string, c echo.Context) error
}

type integrationAuth struct {
	app                core.App
	integrationFetcher data.IntegrationFetcher
}

func NewIntegrationAuth(
	app core.App,
	integrationFetcher data.IntegrationFetcher,
) IntegrationAuth {
	return &integrationAuth{app, integrationFetcher}
}

func (h *integrationAuth) ForIntegration(integrationId string, c echo.Context) error {
	// Get user
	requestInfo := apis.RequestInfo(c)
	if requestInfo.AuthRecord == nil {
		return c.String(http.StatusUnauthorized, "Not logged in")
	}
	loggedInUserId := requestInfo.AuthRecord.Id

	// Get integration
	_, err := h.integrationFetcher.FetchById(data.FetchByIdRequest{
		IntegrationId: integrationId,
		UserId:        loggedInUserId,
	})
	if err != nil {
		// The integration may not exist or may not belong to the user. But
		// probably not worth separating those cases, so just return forbidden.
		return c.String(http.StatusForbidden, "Forbidden")
	}

	return nil
}
