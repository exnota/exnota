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

		collection, err := dao.FindCollectionByNameOrId("shmqo4nddg697ku")
		if err != nil {
			return err
		}

		// update
		edit_blockType := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "jfnfe2yu",
			"name": "blockType",
			"type": "select",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSelect": 1,
				"values": [
					"voice-note"
				]
			}
		}`), edit_blockType); err != nil {
			return err
		}
		collection.Schema.AddField(edit_blockType)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("shmqo4nddg697ku")
		if err != nil {
			return err
		}

		// update
		edit_blockType := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "jfnfe2yu",
			"name": "type",
			"type": "select",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSelect": 1,
				"values": [
					"voice-note"
				]
			}
		}`), edit_blockType); err != nil {
			return err
		}
		collection.Schema.AddField(edit_blockType)

		return dao.SaveCollection(collection)
	})
}
