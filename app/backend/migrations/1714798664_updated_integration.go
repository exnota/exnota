package migrations

import (
	"encoding/json"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models/schema"
	"github.com/pocketbase/pocketbase/tools/types"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cs0n4grobu37qbw")
		if err != nil {
			return err
		}

		collection.ListRule = types.Pointer("user.id = @request.auth.id && archived = null")

		collection.ViewRule = types.Pointer("user.id = @request.auth.id && archived = null")

		collection.UpdateRule = types.Pointer("user.id = @request.auth.id && archived = null")

		collection.DeleteRule = types.Pointer("user.id = @request.auth.id && archived = null")

		// update
		edit_status := &schema.SchemaField{}
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
					"access-revoked",
					"archived"
				]
			}
		}`), edit_status); err != nil {
			return err
		}
		collection.Schema.AddField(edit_status)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cs0n4grobu37qbw")
		if err != nil {
			return err
		}

		collection.ListRule = types.Pointer("user.id = @request.auth.id && archived != null")

		collection.ViewRule = types.Pointer("user.id = @request.auth.id && archived != null")

		collection.UpdateRule = types.Pointer("user.id = @request.auth.id && archived != null")

		collection.DeleteRule = types.Pointer("user.id = @request.auth.id && archived != null")

		// update
		edit_status := &schema.SchemaField{}
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
		}`), edit_status); err != nil {
			return err
		}
		collection.Schema.AddField(edit_status)

		return dao.SaveCollection(collection)
	})
}
