package data

import (
	"errors"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationDataRules interface {
	ApplyHooks()
}

type integrationDataRules struct {
	app core.App
}

func NewIntegrationDataRules(app core.App) IntegrationDataRules {
	return &integrationDataRules{app: app}
}

func (h *integrationDataRules) ApplyHooks() {
	h.app.OnModelBeforeCreate(CollectionIntegration).Add(func(e *core.ModelEvent) error {
		integration := e.Model.(*models.Record)
		userId := integration.GetString(IntegrationFieldUser)
		filter := IntegrationFieldUser + "={:user} && " +
			IntegrationFieldType + "={:type}"
		existingRecord, err := e.Dao.FindRecordsByFilter(
			CollectionIntegration, filter, "-created", 1, 0,
			dbx.Params{"user": userId, "type": IntegrationTypeNotion})
		if err != nil {
			return err
		}
		if len(existingRecord) > 0 {
			return errors.New("user already has a notion integration")
		}

		return nil
	})
}
