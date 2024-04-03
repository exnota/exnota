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

		collection, err := dao.FindCollectionByNameOrId("nnapgn6gas8b3vr")
		if err != nil {
			return err
		}

		// update
		edit_last_synced := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "ytbblb9a",
			"name": "last_synced",
			"type": "date",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"min": "",
				"max": ""
			}
		}`), edit_last_synced); err != nil {
			return err
		}
		collection.Schema.AddField(edit_last_synced)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("nnapgn6gas8b3vr")
		if err != nil {
			return err
		}

		// update
		edit_last_synced := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "ytbblb9a",
			"name": "lastSynced",
			"type": "date",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"min": "",
				"max": ""
			}
		}`), edit_last_synced); err != nil {
			return err
		}
		collection.Schema.AddField(edit_last_synced)

		return dao.SaveCollection(collection)
	})
}
