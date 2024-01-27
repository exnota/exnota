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
		edit_block := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "s6kq9wwb",
			"name": "block",
			"type": "relation",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"collectionId": "lrffu3q1yweoljo",
				"cascadeDelete": false,
				"minSelect": null,
				"maxSelect": 1,
				"displayFields": null
			}
		}`), edit_block)
		collection.Schema.AddField(edit_block)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cml7ayp8msc7q1w")
		if err != nil {
			return err
		}

		// update
		edit_block := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "s6kq9wwb",
			"name": "field",
			"type": "relation",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"collectionId": "lrffu3q1yweoljo",
				"cascadeDelete": false,
				"minSelect": null,
				"maxSelect": 1,
				"displayFields": null
			}
		}`), edit_block)
		collection.Schema.AddField(edit_block)

		return dao.SaveCollection(collection)
	})
}
