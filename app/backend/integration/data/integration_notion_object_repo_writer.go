package data

import (
	"database/sql"
	"errors"
	"time"

	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationNotionObjectWriter interface {
	UpsertRecord(request CreateRequest) (*models.Record, error)
}

type integrationNotionObjectWriter struct {
	app core.App
}

func NewIntegrationNotionObjectWriter(app core.App) IntegrationNotionObjectWriter {
	return &integrationNotionObjectWriter{
		app: app,
	}
}

type CreateRequest struct {
	ExternalId string                      `validate:"required"`
	Type       IntegrationNotionObjectType `validate:"required"`
	Properties map[string]any              `validate:"required"`
	User       string                      `validate:"required"`
}

var validate *validator.Validate = validator.New(validator.WithRequiredStructEnabled())

func (w *integrationNotionObjectWriter) UpsertRecord(request CreateRequest) (*models.Record, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	collection, err := w.app.Dao().FindCollectionByNameOrId(CollectionIntegrationNotionObject)
	if err != nil {
		return nil, err
	}

	// Check if object already exists.
	//
	// Note: This occurs outside the transaction in which the record will be
	// persisted, so there's chance that in between this check and the
	// update/create that the found record will have been deleted or a record
	// will have been created.
	//
	// However, this seems both unlikely and the probable impact is just that
	// the request fails and the user can try again. I don't expect it to create
	// an unexpected state.
	filter := IntegrationNotionObjectFieldExternalId + "={:externalId} && " +
		IntegrationNotionObjectFieldUser + "={:user} && " +
		IntegrationNotionObjectFieldType + "={:type}"
	record, err := w.app.Dao().FindFirstRecordByFilter(CollectionIntegrationNotionObject,
		filter, dbx.Params{
			"externalId": request.ExternalId,
			"user":       request.User,
			"type":       string(request.Type)})

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			// Doesn't exist? Create a new record
			record = models.NewRecord(collection)
			record.Set(IntegrationNotionObjectFieldExternalId, request.ExternalId)
			record.Set(IntegrationNotionObjectFieldType, string(request.Type))
			record.Set(IntegrationNotionObjectFieldUser, request.User)
		} else {
			return nil, err
		}
	}

	// Update the new or existing record
	record.Set(IntegrationNotionObjectFieldProperties, request.Properties)
	record.Set(IntegrationNotionObjectFieldLastSynced, time.Now())
	return record, nil
}
