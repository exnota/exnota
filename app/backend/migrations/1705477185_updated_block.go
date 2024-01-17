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
		new_archived := &schema.SchemaField{}
		json.Unmarshal([]byte(`{
			"system": false,
			"id": "ncyp1jbf",
			"name": "archived",
			"type": "bool",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {}
		}`), new_archived)
		collection.Schema.AddField(new_archived)

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("lrffu3q1yweoljo")
		if err != nil {
			return err
		}

		// remove
		collection.Schema.RemoveField("ncyp1jbf")

		return dao.SaveCollection(collection)
	})
}
