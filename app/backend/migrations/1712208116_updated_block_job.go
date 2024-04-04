package migrations

import (
	"encoding/json"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models/schema"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cml7ayp8msc7q1w")
		if err != nil {
			return err
		}

		if err := json.Unmarshal([]byte(`[
			"CREATE INDEX ` + "`" + `idx_jEfAQ4d` + "`" + ` ON ` + "`" + `block_job` + "`" + ` (` + "`" + `status` + "`" + `)"
		]`), &collection.Indexes); err != nil {
			return err
		}

		// add
		new_next_run_at := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "8hrm63qv",
			"name": "next_run_at",
			"type": "date",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"min": "",
				"max": ""
			}
		}`), new_next_run_at); err != nil {
			return err
		}
		collection.Schema.AddField(new_next_run_at)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cml7ayp8msc7q1w")
		if err != nil {
			return err
		}

		if err := json.Unmarshal([]byte(`[]`), &collection.Indexes); err != nil {
			return err
		}

		// remove
		collection.Schema.RemoveField("8hrm63qv")

		return dao.SaveCollection(collection)
	})
}
