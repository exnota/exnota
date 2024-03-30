package api

import (
	"log/slog"
	"net/url"

	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationEndpointHooks interface {
	Apply()
}

type integrationEndpointHooks struct {
	app    core.App
	config IntegrationEndpointConfig
}

type IntegrationEndpointConfig struct {
	BasePath       string
	NotionClientID string
	// Added this when I thought localhost redirect_uris wouldn't work. Turns
	// out they do but thought I'd leave this here for laziness sake.
	NotionRedirectBasePath string
}

func NewIntegrationEndpointHooks(app core.App, config IntegrationEndpointConfig) IntegrationEndpointHooks {
	return &integrationEndpointHooks{app: app, config: config}
}

func (h *integrationEndpointHooks) Apply() {
	h.mobileCodeRequestPath()
	h.mobileRedirect()
}

const (
	// Use '/api' for consistent base paths and '/api/exnota' to avoid
	// collisions with future PocketBase URLs.
	mobileCodeRequestPath = "/api/exnota/integration/notion/mobile-code-request-path"
	mobileRedirectPath    = "/api/exnota/integration/notion/mobile-code-redirect"
)

// Returns the URL the mobile app should use for getting a Notion auth code. Is
// specific for mobile because the redirect_uri points to mobileRedirect() which
// will redirect to an exnota:// scheme.
func (h *integrationEndpointHooks) mobileCodeRequestPath() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(mobileCodeRequestPath, func(c echo.Context) error {
			redirectUri, err := url.JoinPath(h.config.BasePath, mobileRedirectPath)
			if err != nil {
				return err
			}
			url := "https://api.notion.com/v1/oauth/authorize?client_id=" +
				h.config.NotionClientID +
				"&response_type=code&owner=user&redirect_uri=" +
				url.QueryEscape(redirectUri)

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
func (h *integrationEndpointHooks) mobileRedirect() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(mobileRedirectPath, func(c echo.Context) error {
			code := c.QueryParam("code")
			return c.Redirect(302, "exnota://integration/notion/mobile-code-redirect?code="+code)
		})
		return nil
	})
}
