package api

import (
	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationDestinationApiRules interface {
	ApplyHooks()
}

type integrationDestinationApiRules struct {
	app core.App
}

func NewIntegrationDestinationApiRules(app core.App) IntegrationDestinationApiRules {
	return &integrationDestinationApiRules{app: app}
}

func (h *integrationDestinationApiRules) ApplyHooks() {
	h.blockApiAccessForNonAdmins()
}

func (h *integrationDestinationApiRules) blockApiAccessForNonAdmins() {
	h.app.OnRecordBeforeCreateRequest(integ.CollectionIntegrationDestination).
		Add(func(e *core.RecordCreateEvent) error {

			requestInfo := apis.RequestInfo(e.HttpContext)
			if requestInfo.Admin != nil {
				return nil
			}
			return apis.NewForbiddenError("Not allowed to modify this collection", nil)
		})

	h.app.OnRecordBeforeUpdateRequest(integ.CollectionIntegrationDestination).
		Add(func(e *core.RecordUpdateEvent) error {
			requestInfo := apis.RequestInfo(e.HttpContext)
			if requestInfo.Admin != nil {
				return nil
			}
			return apis.NewForbiddenError("Not allowed to modify this collection", nil)
		})
}
