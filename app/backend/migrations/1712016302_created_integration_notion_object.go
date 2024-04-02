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
			"id": "nnapgn6gas8b3vr",
			"created": "2024-04-02 00:05:02.711Z",
			"updated": "2024-04-02 00:05:02.711Z",
			"name": "integration_notion_object",
			"type": "base",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "w56twhi4",
					"name": "external_id",
					"type": "text",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"min": null,
						"max": null,
						"pattern": ""
					}
				},
				{
					"system": false,
					"id": "vfeyzcnq",
					"name": "type",
					"type": "select",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSelect": 1,
						"values": [
							"page",
							"database",
							"block"
						]
					}
				},
				{
					"system": false,
					"id": "chtljxfq",
					"name": "properties",
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
					"id": "ytbblb9a",
					"name": "lastSynced",
					"type": "date",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"min": "",
						"max": ""
					}
				},
				{
					"system": false,
					"id": "bqwg42gz",
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
			"indexes": [
				"CREATE UNIQUE INDEX ` + "`" + `idx_S1yrke4` + "`" + ` ON ` + "`" + `integration_notion_object` + "`" + ` (\n  ` + "`" + `type` + "`" + `,\n  ` + "`" + `external_id` + "`" + `,\n  ` + "`" + `user` + "`" + `\n)"
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

		collection, err := dao.FindCollectionByNameOrId("nnapgn6gas8b3vr")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
