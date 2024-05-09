package data

import (
	"database/sql"
	"errors"
	"time"

	integ "exnota.com/backend/integration"
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

type integrationNotionObjectWriter struct {
	app core.App
}

func NewIntegrationNotionObjectWriter(app core.App) integ.IntegrationNotionObjectWriter {
	return &integrationNotionObjectWriter{
		app: app,
	}
}

var validate *validator.Validate = validator.New(validator.WithRequiredStructEnabled())

func (w *integrationNotionObjectWriter) CreateUpsertRecord(
	request integ.NotionObjectCreateRequest,
) (*models.Record, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	collection, err := w.app.Dao().
		FindCollectionByNameOrId(integ.CollectionIntegrationNotionObject)
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
	filter := integ.IntegrationNotionObjectFieldExternalId + "={:externalId} && " +
		integ.IntegrationNotionObjectFieldUser + "={:user} && " +
		integ.IntegrationNotionObjectFieldType + "={:type}"
	record, err := w.app.Dao().
		FindFirstRecordByFilter(integ.CollectionIntegrationNotionObject,
			filter, dbx.Params{
				"externalId": request.ExternalId,
				"user":       request.User,
				"type":       string(request.Type)})

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			// Doesn't exist? Create a new record
			record = models.NewRecord(collection)
			// Generate ID so it can be referenced in a transaction. Currently
			// needed so notion_sync.go can return it in its result without
			// having to persist it yet.
			record.BaseModel.RefreshId()
			record.Set(integ.IntegrationNotionObjectFieldExternalId, request.ExternalId)
			record.Set(integ.IntegrationNotionObjectFieldType, string(request.Type))
			record.Set(integ.IntegrationNotionObjectFieldUser, request.User)
		} else {
			return nil, err
		}
	}

	// Update the new or existing record
	record.Set(integ.IntegrationNotionObjectFieldProperties, request.Properties)
	record.Set(integ.IntegrationNotionObjectFieldLastSynced, time.Now())
	record.Set(
		integ.IntegrationNotionObjectFieldStatus,
		lib_integ.NotionObjectStatusConnected,
	)

	// Validate the record, but don't submit
	form := forms.NewRecordUpsert(w.app, record)
	err = form.Validate()
	if err != nil {
		return nil, err
	}

	return record, nil
}

func (w *integrationNotionObjectWriter) UpdateConnected(
	request integ.NotionUpdateSyncConnectedRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	return w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(
			integ.CollectionIntegrationNotionObject,
			request.Id,
		)
		if err != nil {
			return err
		}

		object := integ.LoadIntegrationNotionObject(record, w.app)
		object.SetStatus(lib_integ.NotionObjectStatusConnected)
		object.SetProperties(request.Properties)
		object.SetLastSynced(request.LastSynced)

		if err := object.ValidateAndSubmit(txDao); err != nil {
			return err
		}

		return nil
	})
}

func (w *integrationNotionObjectWriter) UpdateErrored(
	request integ.NotionUpdateSyncErrorRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	return w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(
			integ.CollectionIntegrationNotionObject,
			request.Id,
		)
		if err != nil {
			return err
		}

		object := integ.LoadIntegrationNotionObject(record, w.app)
		object.SetStatus(request.Status)
		object.SetLastSynced(request.LastSynced)

		if err := object.ValidateAndSubmit(txDao); err != nil {
			return err
		}

		return nil
	})
}

func (w *integrationNotionObjectWriter) UpdateArchived(
	request integ.NotionUpdateSyncArchivedRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	return w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(
			integ.CollectionIntegrationNotionObject,
			request.Id,
		)
		if err != nil {
			return err
		}

		object := integ.LoadIntegrationNotionObject(record, w.app)
		object.SetStatus(lib_integ.NotionObjectStatusArchived)
		object.SetProperties(request.Properties)
		object.SetLastSynced(request.LastSynced)

		if err := object.ValidateAndSubmit(txDao); err != nil {
			return err
		}

		return nil
	})
}
