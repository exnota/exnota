package migrations

import (
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		// up
		dao := daos.New(db)
		query := dao.RecordQuery("block")

		records := []*models.Record{}
		if err := query.All(&records); err != nil {
			return err
		}

		// Loop through records
		for _, record := range records {
			// set individual fields
			// or bulk load with record.Load(map[string]any{...})
			record.Set("type", "text")

			if err := dao.SaveRecord(record); err != nil {
				return err
			}
		}

		return nil
	}, func(db dbx.Builder) error {
		// down

		return nil
	})
}
