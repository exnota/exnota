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
		collection.Schema.RemoveField("5enqtw7r")

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("lrffu3q1yweoljo")
		if err != nil {
			return err
		}

		// add
		del_externalUrl := &schema.SchemaField{}
		if err := json.Unmarshal([]byte(`{
			"system": false,
			"id": "5enqtw7r",
			"name": "externalUrl",
			"type": "url",
			"required": false,
			"presentable": false,
			"unique": false,
			"options": {
				"exceptDomains": [],
				"onlyDomains": []
			}
		}`), del_externalUrl); err != nil {
			return err
		}
		collection.Schema.AddField(del_externalUrl)

		return dao.SaveCollection(collection)
	})
}
