package migrations

import (
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		dao := daos.New(db)

		collection, err := dao.FindCollectionByNameOrId("feature")
		if err != nil {
			return err
		}

		record := models.NewRecord(collection)

		record.Load(map[string]any{
			"id":      "6cigtgygahslau6",
			"product": "exnota",
			"nameID":  "VOICE_NOTE",
			"settings": map[string]any{
				"service": "openai",
			},
		})

		if err := dao.SaveRecord(record); err != nil {
			return err
		}

		return nil
	}, func(db dbx.Builder) error {
		dao := daos.New(db)

		record, err := dao.FindRecordById("feature", "6cigtgygahslau6")
		if err != nil {
			return err
		}

		if err := dao.DeleteRecord(record); err != nil {
			return err
		}

		return nil
	})
}
