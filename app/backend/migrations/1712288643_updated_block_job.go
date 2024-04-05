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

		// add
		new_error_count := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "by9xpxiy",
			"name": "error_count",
			"type": "number",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {
				"min": null,
				"max": null,
				"noDecimal": true
			}
		}`), new_error_count); err != nil {
			return err
		}
		collection.Schema.AddField(new_error_count)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cml7ayp8msc7q1w")
		if err != nil {
			return err
		}

		// remove
		collection.Schema.RemoveField("by9xpxiy")

		return dao.SaveCollection(collection)
	})
}
