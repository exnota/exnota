package data

import (
	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type BlockJobWriter interface {
	UpdateStatus(request UpdateStatusRequest) error
}

type blockJobWriter struct {
	app core.App
}

func NewBlockJobWriter(app core.App) BlockJobWriter {
	return &blockJobWriter{app}
}

type UpdateStatusRequest struct {
	Id     string         `validate:"required"`
	Status BlockJobStatus `validate:"required"`
	Error  error
}

var validate *validator.Validate = validator.New(validator.WithRequiredStructEnabled())

func (b *blockJobWriter) UpdateStatus(request UpdateStatusRequest) error {
	if err := validate.Struct(request); err != nil {
		return err
	}

	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(CollectionBlockJob, request.Id)
		if err != nil {
			return err
		}

		blockJob := NewBlockJob(record, b.app)
		blockJob.SetStatus(request.Status)
		if request.Status == BlockJobStatusError && request.Error != nil {
			blockJob.SetSummaryError(request.Error)
		} else {
			blockJob.SetSummaryEmpty()
		}

		return blockJob.ValidateAndSubmit(txDao)
	})
}
