package api

import (
	"encoding/json"
	"log/slog"
	"net/http"
	netUrl "net/url"
	"strings"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase"
	"exnota.com/backend/lib/api"
	"exnota.com/backend/lib/url"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationEndpointHooks interface {
	ApplyHooks()
}

type integrationEndpointHooks struct {
	app    core.App
	config IntegrationEndpointConfig
}

type IntegrationEndpointConfig struct {
	NotionClientID string
}

func NewIntegrationEndpointHooks(
	app core.App,
	config IntegrationEndpointConfig,
) IntegrationEndpointHooks {
	return &integrationEndpointHooks{app: app, config: config}
}

func (h *integrationEndpointHooks) ApplyHooks() {
	// TODO: Move each endpoint into its own file, like update_integration_destination.go
	h.notionMobileCodeRequestPath()
	h.notionMobileRedirect()
	h.integrationVerifyAccess()
}

// Returns the URL the mobile app should use for getting a Notion auth code. Is
// specific for mobile because the redirect_uri points to mobileRedirect() which
// will redirect to an exnota:// scheme.
func (h *integrationEndpointHooks) notionMobileCodeRequestPath() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(api.NotionMobileCodeRequestPath, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.NotionMobileCodeRequestPath,
			)
			redirectUri := url.Url(api.NotionMobileRedirectPath, h.app)
			url := "https://api.notion.com/v1/oauth/authorize?client_id=" +
				h.config.NotionClientID +
				"&response_type=code&owner=user&redirect_uri=" +
				netUrl.QueryEscape(redirectUri)

			// Manually constract this using a string + c.JSONBlob because
			// using json.Marshall (or c.JSON(), which calls json.Marshall) will
			// escape the redirect_uri.
			resp := `{"url":"` + url +
				`"}`
			slog.Info("", "json", resp)
			return c.JSONBlob(200, []byte(resp))
		})
		return nil
	})
}

// Redirects to an exnota:// scheme for the mobile app to capture and read.
func (h *integrationEndpointHooks) notionMobileRedirect() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(api.NotionMobileRedirectPath, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.NotionMobileRedirectPath,
			)
			code := c.QueryParam("code")
			return c.Redirect(302, "exnota://integration/notion/mobile-code-redirect?code="+code)
		})
		return nil
	})
}

type VerifyIntegrationAccessRequest struct {
	IntegrationId string `json:"integration_id"`
}

type VerifyIntegrationAccessResponse struct {
	Result VerifyIntegrationAccessResult
}

type VerifyIntegrationAccessResult string

const (
	Success      VerifyIntegrationAccessResult = "success"
	InvalidToken VerifyIntegrationAccessResult = "invalid-token"
)

func (r VerifyIntegrationAccessResponse) MarshalJSON() ([]byte, error) {
	return json.Marshal(struct {
		Result string `json:"result"`
	}{
		Result: string(r.Result),
	})
}

func (h *integrationEndpointHooks) integrationVerifyAccess() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.POST(api.IntegrationVerifyAccess, func(c echo.Context) error {
			slog.Info(
				"Custom endpoint",
				"method",
				c.Request().Method,
				"path",
				api.IntegrationVerifyAccess,
			)

			verifyRequest := new(VerifyIntegrationAccessRequest)
			if err := c.Bind(verifyRequest); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}

			integrationId := verifyRequest.IntegrationId
			if strings.TrimSpace(integrationId) == "" {
				return c.JSON(http.StatusBadRequest, nil)
			}

			auth := NewIntegrationAuth(h.app, data.NewIntegrationFetcher(h.app), c)
			err := auth.ForIntegration(integrationId)
			if err != nil {
				return err
			}

			requestInfo := apis.RequestInfo(c)
			if requestInfo.AuthRecord == nil {
				return c.String(http.StatusUnauthorized, "Not logged in")
			}
			loggedInUserId := requestInfo.AuthRecord.Id

			integrationSync := usecase.NewIntegrationSync(h.app)
			success, err := integrationSync.UpdateStatus(usecase.UpdateStatusRequest{
				IntegrationId: integrationId,
				UserID:        loggedInUserId,
			})
			if err != nil {
				return c.JSON(http.StatusInternalServerError, nil)
			}

			if success {
				return c.JSON(http.StatusOK, VerifyIntegrationAccessResponse{
					Result: Success,
				})
			} else {
				return c.JSON(http.StatusOK, VerifyIntegrationAccessResponse{
					Result: InvalidToken,
				})
			}

		})
		return nil
	})
}
