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
			"id": "shmqo4nddg697ku",
			"created": "2024-04-11 05:07:32.911Z",
			"updated": "2024-04-11 05:07:32.911Z",
			"name": "integration_block_notion_mapping",
			"type": "base",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "jfnfe2yu",
					"name": "type",
					"type": "select",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSelect": 1,
						"values": [
							"voice-note"
						]
					}
				},
				{
					"system": false,
					"id": "xqfhb5un",
					"name": "internalBlock",
					"type": "relation",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"collectionId": "lrffu3q1yweoljo",
						"cascadeDelete": false,
						"minSelect": null,
						"maxSelect": 1,
						"displayFields": null
					}
				},
				{
					"system": false,
					"id": "cof4ning",
					"name": "internalDestination",
					"type": "relation",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"collectionId": "cxt29m6rizjvyi8",
						"cascadeDelete": false,
						"minSelect": null,
						"maxSelect": 1,
						"displayFields": null
					}
				},
				{
					"system": false,
					"id": "sgsnpwb0",
					"name": "externalBlock",
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
					"id": "duws7tdn",
					"name": "externalDestination",
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
					"id": "foqryojf",
					"name": "externalUrl",
					"type": "url",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"exceptDomains": [],
						"onlyDomains": []
					}
				},
				{
					"system": false,
					"id": "jnseehaw",
					"name": "config",
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
				"CREATE UNIQUE INDEX ` + "`" + `idx_bjwZPH9` + "`" + ` ON ` + "`" + `integration_block_notion_mapping` + "`" + ` (` + "`" + `internalBlock` + "`" + `)"
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

		collection, err := dao.FindCollectionByNameOrId("shmqo4nddg697ku")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
