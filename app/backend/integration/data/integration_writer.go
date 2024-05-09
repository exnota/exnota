package data

import (
	"errors"

	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type IntegrationWriter interface {
	SetStatus(request SetStatusRequest) error
}

type integrationWriter struct {
	app   core.App
	txDao *daos.Dao
}

func NewIntegrationWriter(app core.App, txDao *daos.Dao) IntegrationWriter {
	return &integrationWriter{app, txDao}
}

type SetStatusRequest struct {
	Id     string                  `validate:"min=1"`
	UserId string                  `validate:"min=1"`
	Status integ.IntegrationStatus `validate:"required"`
}

func (w *integrationWriter) SetStatus(request SetStatusRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	record, err := w.txDao.FindRecordById(integ.CollectionIntegration, request.Id)
	if err != nil {
		return err
	}

	integration, err := integ.LoadIntegration(record, w.app)
	if err != nil {
		return err
	}

	if integration.User() != request.UserId {
		return errors.New("user does not own integration")
	}

	integration.SetStatus(request.Status)
	return integration.ValidateAndSubmit(w.txDao)
}
