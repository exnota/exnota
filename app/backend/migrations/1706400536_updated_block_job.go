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

		// update
		edit_summary := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "jn7xm7j9",
			"name": "summary",
			"type": "json",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSize": 2000000
			}
		}`), edit_summary)
		collection.Schema.AddField(edit_summary)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cml7ayp8msc7q1w")
		if err != nil {
			return err
		}

		// update
		edit_summary := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "jn7xm7j9",
			"name": "summary",
			"type": "json",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSize": 2000000
			}
		}`), edit_summary)
		collection.Schema.AddField(edit_summary)

		return dao.SaveCollection(collection)
	})
}
