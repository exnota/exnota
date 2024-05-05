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

		collection, err := dao.FindCollectionByNameOrId("nxuftggamjjawjp")
		if err != nil {
			return err
		}

		collection.ListRule = types.Pointer("user.id = @request.auth.id && archived = null")

		collection.ViewRule = types.Pointer("user.id = @request.auth.id && archived = null")

		collection.CreateRule = types.Pointer("user.id = @request.auth.id && archived = null")

		collection.UpdateRule = types.Pointer("user.id = @request.auth.id && archived = null")

		// add
		new_archived := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "kmbcklxq",
			"name": "archived",
			"type": "date",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {
				"min": "",
				"max": ""
			}
		}`), new_archived); err != nil {
			return err
		}
		collection.Schema.AddField(new_archived)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("nxuftggamjjawjp")
		if err != nil {
			return err
		}

		collection.ListRule = types.Pointer("user.id = @request.auth.id")

		collection.ViewRule = types.Pointer("user.id = @request.auth.id")

		collection.CreateRule = types.Pointer("user.id = @request.auth.id")

		collection.UpdateRule = types.Pointer("user.id = @request.auth.id")

		// remove
		collection.Schema.RemoveField("kmbcklxq")

		return dao.SaveCollection(collection)
	})
}
