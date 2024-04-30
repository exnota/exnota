package data

import (
	"database/sql"
	"errors"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationDestinationWriter interface {
	Upsert(data IntegrationDestinationUpsertData) error
}

type integrationDestinationWriter struct {
	app   core.App
	txDao *daos.Dao
}

func NewIntegrationDestinationWriter(app core.App, txDao *daos.Dao) IntegrationDestinationWriter {
	return &integrationDestinationWriter{app: app, txDao: txDao}
}

type IntegrationDestinationUpsertData struct {
	DestinationId      string
	ExternalRecordType IntegrationDestinationRecordType
	ExternalRecordId   string
	User               string
}

func (m *integrationDestinationWriter) Upsert(data IntegrationDestinationUpsertData) error {
	var dao *daos.Dao
	if m.txDao != nil {
		dao = m.txDao
	} else {
		dao = m.app.Dao()
	}

	err := dao.RunInTransaction(func(dao *daos.Dao) error {
		collection, err := dao.FindCollectionByNameOrId(CollectionIntegrationDestination)
		if err != nil {
			return err
		}

		// Check if object already exists.
		filter := IntegrationDestinationFieldExternalRecordId + "={:externalRecordId} && " +
			IntegrationDestinationFieldExternalRecordType + "={:externalRecordType}"
		existing, err := dao.FindFirstRecordByFilter(CollectionIntegrationDestination,
			filter, dbx.Params{
				"externalRecordId":   data.ExternalRecordId,
				"externalRecordType": string(data.ExternalRecordType),
			},
		)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				// If it doesn't exist, create a new record.
				// Fallthrough to below.
			} else {
				return err
			}
		} else {
			// If it does exist but the requested user or destination are
			// different, throw an error because that shouldn't happen.
			if existing.GetString(IntegrationDestinationFieldDestinationId) != data.DestinationId {
				return errors.New("IntegrationDestinationUpsertData: Attempted to change destination from " +
					existing.GetString(IntegrationDestinationFieldDestinationId) + " to " +
					data.DestinationId)
			}
			if existing.Get(IntegrationDestinationFieldUser) != data.User {
				return errors.New("IntegrationDestinationUpsertData: Attempted to change user from " +
					existing.GetString(IntegrationDestinationFieldUser) + " to " +
					data.User)
			}

			// If everything is the same, no reason to update.
			return nil
		}

		// Create new record
		record := models.NewRecord(collection)
		record.Set(IntegrationDestinationFieldDestinationId, data.DestinationId)
		record.Set(IntegrationDestinationFieldExternalRecordType, string(data.ExternalRecordType))
		record.Set(IntegrationDestinationFieldExternalRecordId, data.ExternalRecordId)
		record.Set(IntegrationDestinationFieldUser, data.User)

		form := forms.NewRecordUpsert(m.app, record)
		form.SetDao(dao)
		if err := form.Validate(); err != nil {
			return err
		}
		if err := form.Submit(); err != nil {
			return err
		}

		return nil
	})

	return err
}
