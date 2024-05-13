package api

import (
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type AuthBase interface {
	LoggedInUser() string
}

type Base struct {
	App     core.App
	Context echo.Context
}

func NewIntegrationAuth(
	app core.App,
	context echo.Context,
) AuthBase {
	return &Base{app, context}
}

func (h *Base) LoggedInUser() string {
	requestInfo := apis.RequestInfo(h.Context)
	if requestInfo.AuthRecord == nil {
		return ""
	}
	return requestInfo.AuthRecord.Id
}
