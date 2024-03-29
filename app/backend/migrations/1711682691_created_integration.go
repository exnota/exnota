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
			"id": "cs0n4grobu37qbw",
			"created": "2024-03-29 03:24:51.571Z",
			"updated": "2024-03-29 03:24:51.571Z",
			"name": "integration",
			"type": "base",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "7wxfrr7w",
					"name": "type",
					"type": "select",
					"required": true,
					"presentable": true,
					"unique": false,
					"options": {
						"maxSelect": 1,
						"values": [
							"notion"
						]
					}
				},
				{
					"system": false,
					"id": "q03rxpwf",
					"name": "config",
					"type": "json",
					"required": false,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSize": 2000000
					}
				},
				{
					"system": false,
					"id": "yiuhg6xu",
					"name": "user",
					"type": "relation",
					"required": true,
					"presentable": true,
					"unique": false,
					"options": {
						"collectionId": "_pb_users_auth_",
						"cascadeDelete": false,
						"minSelect": null,
						"maxSelect": 1,
						"displayFields": null
					}
				}
			],
			"indexes": [],
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

		collection, err := dao.FindCollectionByNameOrId("cs0n4grobu37qbw")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
