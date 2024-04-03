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

		collection, err := dao.FindCollectionByNameOrId("c0w1e7tkjs4twsk")
		if err != nil {
			return err
		}

		if err := json.Unmarshal([]byte(`[
			"CREATE UNIQUE INDEX ` + "`" + `idx_CdxTQk4` + "`" + ` ON ` + "`" + `integration_destination` + "`" + ` (\n  ` + "`" + `external_record_type` + "`" + `,\n  ` + "`" + `external_record_id` + "`" + `\n)"
		]`), &collection.Indexes); err != nil {
			return err
		}

		// update
		edit_external_record_type := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "zdkc2cyp",
			"name": "external_record_type",
			"type": "select",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSelect": 1,
				"values": [
					"notion"
				]
			}
		}`), edit_external_record_type); err != nil {
			return err
		}
		collection.Schema.AddField(edit_external_record_type)

		// update
		edit_external_record_id := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "ju1olttz",
			"name": "external_record_id",
			"type": "text",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"min": null,
				"max": null,
				"pattern": ""
			}
		}`), edit_external_record_id); err != nil {
			return err
		}
		collection.Schema.AddField(edit_external_record_id)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("c0w1e7tkjs4twsk")
		if err != nil {
			return err
		}

		if err := json.Unmarshal([]byte(`[]`), &collection.Indexes); err != nil {
			return err
		}

		// update
		edit_external_record_type := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "zdkc2cyp",
			"name": "external_type",
			"type": "select",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSelect": 1,
				"values": [
					"notion"
				]
			}
		}`), edit_external_record_type); err != nil {
			return err
		}
		collection.Schema.AddField(edit_external_record_type)

		// update
		edit_external_record_id := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "ju1olttz",
			"name": "external_id",
			"type": "text",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"min": null,
				"max": null,
				"pattern": ""
			}
		}`), edit_external_record_id); err != nil {
			return err
		}
		collection.Schema.AddField(edit_external_record_id)

		return dao.SaveCollection(collection)
	})
}
