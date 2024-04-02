package api

import (
	"exnota.com/backend/integration/data"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationNotionObjectApiRules interface {
	ApplyHooks()
}

type integrationNotionObjectApiRules struct {
	app core.App
}

func NewIntegrationNotionObjectApiRules(app core.App) IntegrationNotionObjectApiRules {
	return &integrationNotionObjectApiRules{app: app}
}

func (h *integrationNotionObjectApiRules) ApplyHooks() {
	h.blockApiAccessForNonAdmins()
}

func (h *integrationNotionObjectApiRules) blockApiAccessForNonAdmins() {
	h.app.OnRecordBeforeCreateRequest(data.CollectionIntegrationNotionObject).Add(func(e *core.RecordCreateEvent) error {

		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}
		return apis.NewForbiddenError("Not allowed to modify this collection", nil)
	})

	h.app.OnRecordBeforeUpdateRequest(data.CollectionIntegrationNotionObject).Add(func(e *core.RecordUpdateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}
		return apis.NewForbiddenError("Not allowed to modify this collection", nil)
	})
}
