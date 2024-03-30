package api

import (
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationEndpointHooks interface {
	Apply()
}

type integrationEndpointHooks struct {
	app core.App
}

func NewIntegrationEndpointHooks(app core.App) IntegrationEndpointHooks {
	return &integrationEndpointHooks{app: app}
}

func (h *integrationEndpointHooks) Apply() {
	h.mobileRedirect()
}

func (h *integrationEndpointHooks) mobileRedirect() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET("/integration/notion/mobile-code-redirect", func(c echo.Context) error {
			code := c.QueryParam("code")
			return c.Redirect(302, "exnota://integration/notion/mobile-code-redirect?code="+code)
		})
		return nil
	})
}
