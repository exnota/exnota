package migrations

import (
	"encoding/json"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("c0w1e7tkjs4twsk")
		if err != nil {
			return err
		}

		if err := json.Unmarshal([]byte(`[
			"CREATE UNIQUE INDEX ` + "`" + `idx_CdxTQk4` + "`" + ` ON ` + "`" + `integration_destination` + "`" + ` (\n  ` + "`" + `external_record_type` + "`" + `,\n  ` + "`" + `external_record_id` + "`" + `,\n  ` + "`" + `destination_id` + "`" + `\n)",
			"CREATE UNIQUE INDEX ` + "`" + `idx_aryXBYe` + "`" + ` ON ` + "`" + `integration_destination` + "`" + ` (` + "`" + `destination_id` + "`" + `)"
		]`), &collection.Indexes); err != nil {
			return err
		}

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("c0w1e7tkjs4twsk")
		if err != nil {
			return err
		}

		if err := json.Unmarshal([]byte(`[
			"CREATE UNIQUE INDEX ` + "`" + `idx_CdxTQk4` + "`" + ` ON ` + "`" + `integration_destination` + "`" + ` (\n  ` + "`" + `external_record_type` + "`" + `,\n  ` + "`" + `external_record_id` + "`" + `\n)",
			"CREATE UNIQUE INDEX ` + "`" + `idx_aryXBYe` + "`" + ` ON ` + "`" + `integration_destination` + "`" + ` (` + "`" + `destination_id` + "`" + `)"
		]`), &collection.Indexes); err != nil {
			return err
		}

		return dao.SaveCollection(collection)
	})
}
