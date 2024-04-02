package api

import (
	"exnota.com/backend/block/data"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type DestinationApiRules interface {
	ApplyHooks()
}

type destinationApiRules struct {
	app core.App
}

func NewDestinationApiRules(app core.App) DestinationApiRules {
	return &destinationApiRules{app: app}
}

func (h *destinationApiRules) ApplyHooks() {
	h.blockApiAccessForNonAdmins()
}

func (h *destinationApiRules) blockApiAccessForNonAdmins() {
	h.app.OnRecordBeforeUpdateRequest(data.CollectionDestination).Add(func(e *core.RecordUpdateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}
		return apis.NewForbiddenError("Not allowed to modify this collection", nil)
	})
}
