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
			"id": "c0w1e7tkjs4twsk",
			"created": "2024-04-02 02:14:46.480Z",
			"updated": "2024-04-02 02:14:46.480Z",
			"name": "integration_destination",
			"type": "base",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "jrqkrcb5",
					"name": "destination_id",
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
					"id": "zdkc2cyp",
					"name": "external_type",
					"type": "select",
					"required": true,
					"presentable": false,
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
					"id": "ju1olttz",
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

		collection, err := dao.FindCollectionByNameOrId("c0w1e7tkjs4twsk")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
