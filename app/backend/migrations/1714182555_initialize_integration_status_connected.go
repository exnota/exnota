package migrations

import (
	"log/slog"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		// up - set all integrations to 'connected'
		dao := daos.New(db)
		query := dao.RecordQuery("integration")

		records := []*models.Record{}
		if err := query.All(&records); err != nil {
			return err
		}

		// Loop through records
		for _, record := range records {
			// set individual fields
			// or bulk load with record.Load(map[string]any{...})
			record.Set("status", "connected")

			if err := dao.SaveRecord(record); err != nil {
				return err
			}
		}
		slog.Info("Updated integration statuses to connected", "count", len(records))

		return nil
	}, func(db dbx.Builder) error {
		// down - set all integration statuses as empty
		dao := daos.New(db)
		query := dao.RecordQuery("integration")

		records := []*models.Record{}
		if err := query.All(&records); err != nil {
			return err
		}

		// Loop through records
		for _, record := range records {
			// set individual fields
			// or bulk load with record.Load(map[string]any{...})
			record.Set("status", nil)

			if err := dao.SaveRecord(record); err != nil {
				return err
			}
		}

		slog.Info("Cleared integration statuses", "count", len(records))

		return nil
	})
}
