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
			"id": "nxuftggamjjawjp",
			"created": "2024-04-01 05:33:04.055Z",
			"updated": "2024-04-01 05:33:04.055Z",
			"name": "workspace",
			"type": "base",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "m2sxlmlx",
					"name": "name",
					"type": "text",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"min": 1,
						"max": null,
						"pattern": ""
					}
				},
				{
					"system": false,
					"id": "bm0av1j6",
					"name": "type",
					"type": "select",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSelect": 1,
						"values": [
							"database",
							"custom"
						]
					}
				},
				{
					"system": false,
					"id": "pgh72vg9",
					"name": "integration",
					"type": "relation",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"collectionId": "cs0n4grobu37qbw",
						"cascadeDelete": false,
						"minSelect": null,
						"maxSelect": 1,
						"displayFields": null
					}
				},
				{
					"system": false,
					"id": "gjaarykv",
					"name": "icon",
					"type": "url",
					"required": false,
					"presentable": false,
					"unique": false,
					"options": {
						"exceptDomains": [],
						"onlyDomains": []
					}
				},
				{
					"system": false,
					"id": "isg7uuzh",
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

		collection, err := dao.FindCollectionByNameOrId("nxuftggamjjawjp")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
