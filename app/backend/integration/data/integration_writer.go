package data

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type IntegrationWriter interface {
	SetStatus(request SetStatusRequest) error
}

type integrationWriter struct {
	app core.App
}

func NewIntegrationWriter(app core.App) IntegrationWriter {
	return &integrationWriter{app}
}

type SetStatusRequest struct {
	Id     string            `validate:"min=1"`
	UserId string            `validate:"min=1"`
	Status IntegrationStatus `validate:"required"`
}

func (w *integrationWriter) SetStatus(request SetStatusRequest) error {
	return w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		err := validate.Struct(request)
		if err != nil {
			return err
		}

		record, err := w.app.Dao().FindRecordById(CollectionIntegration, request.Id)
		if err != nil {
			return err
		}

		integration, err := LoadIntegration(record, w.app)
		if err != nil {
			return err
		}

		if integration.User() != request.UserId {
			return errors.New("user does not own integration")
		}

		integration.SetStatus(request.Status)
		return integration.ValidateAndSubmit(txDao)
	})
}
