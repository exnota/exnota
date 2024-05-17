package data

import (
	"database/sql"
	"errors"
	"fmt"
	"log/slog"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/lib/data/filter"
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
	ExternalRecordType integ.IntegrationDestinationRecordType
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
		collection, err := dao.FindCollectionByNameOrId(
			integ.CollectionIntegrationDestination,
		)
		if err != nil {
			return err
		}

		// Check if a mapping already exists
		filter, err := filter.CreateAndFilter(
			filter.Field{
				Name:  integ.IntegrationDestinationFieldDestinationId,
				Op:    filter.OpEquals,
				Value: data.DestinationId,
			},
			filter.Field{
				Name:  integ.IntegrationDestinationFieldExternalRecordType,
				Op:    filter.OpEquals,
				Value: string(data.ExternalRecordType),
			},
			filter.Field{
				Name:  integ.IntegrationDestinationFieldExternalRecordId,
				Op:    filter.OpEquals,
				Value: data.ExternalRecordId,
			},
		)
		if err != nil {
			return err
		}
		_, err = dao.FindFirstRecordByFilter(integ.CollectionIntegrationDestination,
			filter.Filter,
			filter.Params,
		)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				// If it doesn't exist, create a new record.
				// Fallthrough to below.
			} else {
				return fmt.Errorf("Error finding existing record: %w", err)
			}
		} else {
			// Already exists, no-op
			slog.Info("Integration destination already exists", "destination_id", data.DestinationId)
			return nil
		}

		// Create new record
		record := models.NewRecord(collection)
		record.Set(integ.IntegrationDestinationFieldDestinationId, data.DestinationId)
		record.Set(
			integ.IntegrationDestinationFieldExternalRecordType,
			string(data.ExternalRecordType),
		)
		record.Set(integ.IntegrationDestinationFieldExternalRecordId, data.ExternalRecordId)
		record.Set(integ.IntegrationDestinationFieldUser, data.User)

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
