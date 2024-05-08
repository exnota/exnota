package api

import (
	"net/http"

	"exnota.com/backend/integration/data"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationAuth interface {
	LoggedInUser() string

	// Returns an error if the logged in user user does not have access to the
	// integration.
	ForIntegration(integrationId string) error
}

type integrationAuth struct {
	app                core.App
	integrationFetcher data.IntegrationFetcher
	context            echo.Context
}

func NewIntegrationAuth(
	app core.App,
	integrationFetcher data.IntegrationFetcher,
	context echo.Context,
) IntegrationAuth {
	return &integrationAuth{app, integrationFetcher, context}
}

// LoggedInUser implements IntegrationAuth.
func (h *integrationAuth) LoggedInUser() string {
	// Get user
	requestInfo := apis.RequestInfo(h.context)
	if requestInfo.AuthRecord == nil {
		return ""
	}
	return requestInfo.AuthRecord.Id
}

func (h *integrationAuth) ForIntegration(integrationId string) error {
	// Get user
	loggedInUserId := h.LoggedInUser()
	if loggedInUserId == "" {
		return h.context.String(http.StatusUnauthorized, "Not logged in")
	}

	// Get integration
	_, err := h.integrationFetcher.FetchById(data.FetchByIdRequest{
		IntegrationId: integrationId,
		UserId:        loggedInUserId,
	})
	if err != nil {
		// The integration may not exist or may not belong to the user. But
		// probably not worth separating those cases, so just return forbidden.
		return h.context.String(http.StatusForbidden, "Forbidden")
	}

	return nil
}
