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
			"id": "54a5qace7zweo78",
			"created": "2024-06-12 10:29:16.477Z",
			"updated": "2024-06-12 10:29:16.477Z",
			"name": "user_feature_settings",
			"type": "view",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "tpbdg8jn",
					"name": "user",
					"type": "json",
					"required": false,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSize": 1
					}
				},
				{
					"system": false,
					"id": "jerx3nu0",
					"name": "feature",
					"type": "relation",
					"required": false,
					"presentable": false,
					"unique": false,
					"options": {
						"collectionId": "f40ip2n5h5wa54h",
						"cascadeDelete": false,
						"minSelect": null,
						"maxSelect": 1,
						"displayFields": null
					}
				},
				{
					"system": false,
					"id": "viimlb1w",
					"name": "featureNameID",
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
					"id": "ogx8wzhm",
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
					"id": "hen8uxel",
					"name": "settings",
					"type": "json",
					"required": false,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSize": 1
					}
				}
			],
			"indexes": [],
			"listRule": null,
			"viewRule": null,
			"createRule": null,
			"updateRule": null,
			"deleteRule": null,
			"options": {
				"query": "SELECT \n    (user.id || '-' || feature.id) AS id,\n    user.id AS user, \n    feature.id AS feature, \n    feature.` + "`" + `nameID` + "`" + ` AS featureNameID,\n    feature.product AS product,\n    json_patch(\n        COALESCE(NULLIF(feature.settings, ''), '{}'),\n        COALESCE(\n          JSON_EXTRACT(\n            COALESCE(\n              NULLIF(user.` + "`" + `featureSettings` + "`" + `, ''), '{}' )\n            , '$.' || feature.product || '.' || feature.` + "`" + `nameID` + "`" + `),\n          '{}')\n      ) as settings\nFROM \n    user \nCROSS JOIN \n    feature; "
			}
		}`

		collection := &models.Collection{}
		if err := json.Unmarshal([]byte(jsonData), &collection); err != nil {
			return err
		}

		return daos.New(db).SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("54a5qace7zweo78")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
