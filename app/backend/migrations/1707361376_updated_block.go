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

		// remove
		collection.Schema.RemoveField("ncyp1jbf")

		// add
		new_userCreated := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "ezcwodok",
			"name": "userCreated",
			"type": "date",
			"required": true,
			"presentable": false,
			"unique": false,
			"options": {
				"min": "",
				"max": ""
			}
		}`), new_userCreated)
		collection.Schema.AddField(new_userCreated)

		// add
		new_archived := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "1tjwkuvk",
			"name": "archived",
			"type": "date",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {
				"min": "",
				"max": ""
			}
		}`), new_archived)
		collection.Schema.AddField(new_archived)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("lrffu3q1yweoljo")
		if err != nil {
			return err
		}

		// add
		del_archived := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "ncyp1jbf",
			"name": "archived",
			"type": "bool",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {}
		}`), del_archived)
		collection.Schema.AddField(del_archived)

		// remove
		collection.Schema.RemoveField("ezcwodok")

		// remove
		collection.Schema.RemoveField("1tjwkuvk")

		return dao.SaveCollection(collection)
	})
}
