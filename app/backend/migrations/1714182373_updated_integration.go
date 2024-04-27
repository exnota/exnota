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

		collection, err := dao.FindCollectionByNameOrId("cs0n4grobu37qbw")
		if err != nil {
			return err
		}

		// add
		new_status := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "xovgw1pl",
			"name": "status",
			"type": "select",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"maxSelect": 1,
				"values": [
					"connected",
					"access-revoked"
				]
			}
		}`), new_status); err != nil {
			return err
		}
		collection.Schema.AddField(new_status)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cs0n4grobu37qbw")
		if err != nil {
			return err
		}

		// remove
		collection.Schema.RemoveField("xovgw1pl")

		return dao.SaveCollection(collection)
	})
}
