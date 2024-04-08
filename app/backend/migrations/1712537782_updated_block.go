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

		collection, err := dao.FindCollectionByNameOrId("lrffu3q1yweoljo")
		if err != nil {
			return err
		}

		// add
		new_external := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "mahw3tcj",
			"name": "external",
			"type": "json",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSize": 2000000
			}
		}`), new_external); err != nil {
			return err
		}
		collection.Schema.AddField(new_external)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("lrffu3q1yweoljo")
		if err != nil {
			return err
		}

		// remove
		collection.Schema.RemoveField("mahw3tcj")

		return dao.SaveCollection(collection)
	})
}
