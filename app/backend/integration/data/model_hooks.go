package modelhooks

import (
	"errors"

	integ "exnota.com/backend/integration"
	"github.com/pocketbase/dbx"
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
		filter := integ.IntegrationFieldUser + "={:user} && " +
			integ.IntegrationFieldType + "={:type}"
		existingRecord, err := e.Dao.FindRecordsByFilter(
			integ.CollectionIntegration, filter, "-created", 1, 0,
			dbx.Params{"user": userId, "type": integ.IntegrationTypeNotion})
		if err != nil {
			return err
		}
		if len(existingRecord) > 0 {
			return errors.New("user already has a notion integration")
		}

		return nil
	})
}
