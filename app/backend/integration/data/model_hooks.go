package modelhooks

import (
	"errors"

	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type ModelHooks interface {
	Apply()
}

type modelHooks struct {
	app core.App
}

func NewModelHooks(app core.App) ModelHooks {
	return &modelHooks{app: app}
}

func (h *modelHooks) Apply() {
	h.app.OnModelBeforeCreate(integ.CollectionIntegration).Add(func(e *core.ModelEvent) error {
		integration := e.Model.(*models.Record)
		userId := integration.GetString(integ.IntegrationFieldUser)
		existingRecord, err := e.Dao.FindFirstRecordByData(integ.CollectionIntegration, integ.IntegrationFieldUser, userId)
		if err != nil {
			return err
		}
		if existingRecord != nil {
			return errors.New("user already has an integration")
		}

		return nil
	})
}
