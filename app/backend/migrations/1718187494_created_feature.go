package migrations

import (
	"encoding/json"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		jsonData := `{
			"id": "f40ip2n5h5wa54h",
			"created": "2024-06-12 10:18:14.574Z",
			"updated": "2024-06-12 10:18:14.574Z",
			"name": "feature",
			"type": "base",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "b1hqpr8q",
					"name": "nameID",
					"type": "text",
					"required": false,
					"presentable": true,
					"unique": false,
					"options": {
						"min": null,
						"max": null,
						"pattern": "^[A-Z]+(_[A-Z]+)*$"
					}
				},
				{
					"system": false,
					"id": "oyodjanq",
					"name": "product",
					"type": "select",
					"required": false,
					"presentable": true,
					"unique": false,
					"options": {
						"maxSelect": 1,
						"values": [
							"exnota"
						]
					}
				},
				{
					"system": false,
					"id": "hvylyh3b",
					"name": "settings",
					"type": "json",
					"required": false,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSize": 2000000
					}
				}
			],
			"indexes": [
				"CREATE UNIQUE INDEX ` + "`" + `idx_8wk7BVt` + "`" + ` ON ` + "`" + `feature` + "`" + ` (` + "`" + `nameID` + "`" + `)"
			],
			"listRule": null,
			"viewRule": null,
			"createRule": null,
			"updateRule": null,
			"deleteRule": null,
			"options": {}
		}`

		collection := &models.Collection{}
		if err := json.Unmarshal([]byte(jsonData), &collection); err != nil {
			return err
		}

		return daos.New(db).SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("f40ip2n5h5wa54h")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
