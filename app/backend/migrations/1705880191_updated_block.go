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

		json.Unmarshal([]byte(`[
			"CREATE INDEX ` + "`" + `idx_asPW1yE` + "`" + ` ON ` + "`" + `block` + "`" + ` (` + "`" + `user` + "`" + `)"
		]`), &collection.Indexes)

		// remove
		collection.Schema.RemoveField("ssbhpyyj")

		// add
		new_user := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "70soquhx",
			"name": "user",
			"type": "relation",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"collectionId": "_pb_users_auth_",
				"cascadeDelete": false,
				"minSelect": null,
				"maxSelect": 1,
				"displayFields": null
			}
		}`), new_user)
		collection.Schema.AddField(new_user)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("lrffu3q1yweoljo")
		if err != nil {
			return err
		}

		json.Unmarshal([]byte(`[
			"CREATE INDEX ` + "`" + `idx_Zrp188g` + "`" + ` ON ` + "`" + `block` + "`" + ` (` + "`" + `user` + "`" + `)"
		]`), &collection.Indexes)

		// add
		del_user := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "ssbhpyyj",
			"name": "user",
			"type": "relation",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"collectionId": "_pb_users_auth_",
				"cascadeDelete": false,
				"minSelect": null,
				"maxSelect": 1,
				"displayFields": null
			}
		}`), del_user)
		collection.Schema.AddField(del_user)

		// remove
		collection.Schema.RemoveField("70soquhx")

		return dao.SaveCollection(collection)
	})
}
