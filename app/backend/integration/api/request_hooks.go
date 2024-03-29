package requesthooks

import (
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type RequestHooks interface {
	Apply()
}

type requestHooks struct {
	app core.App
}

func NewRequestHooks(app core.App) RequestHooks {
	return &requestHooks{app: app}
}

const (
	CollectionIntegration = "integration"
	IntegrationFieldUser  = "user"
)

func (h *requestHooks) Apply() {
	h.app.OnModelBeforeCreate(CollectionIntegration).Add(func(e *core.ModelEvent) error {
		integration := e.Model.(*models.Record)
		userId := integration.GetString(IntegrationFieldUser)
		existingRecord, err := e.Dao.FindFirstRecordByData(CollectionIntegration, IntegrationFieldUser, userId)
		if err != nil {
			return err
		}
		if existingRecord != nil {
			return apis.NewBadRequestError("user already has an integration", nil)
		}

		return nil
	})
}
