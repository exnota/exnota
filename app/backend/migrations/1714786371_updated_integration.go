package migrations

import (
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cs0n4grobu37qbw")
		if err != nil {
			return err
		}

		collection.ListRule = types.Pointer("user.id = @request.auth.id && archived != null")

		collection.ViewRule = types.Pointer("user.id = @request.auth.id && archived != null")

		collection.UpdateRule = types.Pointer("user.id = @request.auth.id && archived != null")

		collection.DeleteRule = types.Pointer("user.id = @request.auth.id && archived != null")

		return dao.SaveCollection(collection)
	}, func(db dbx.Builder) error {
		dao := daos.New(db);

		collection, err := dao.FindCollectionByNameOrId("cs0n4grobu37qbw")
		if err != nil {
			return err
		}

		collection.ListRule = types.Pointer("user.id = @request.auth.id")

		collection.ViewRule = types.Pointer("user.id = @request.auth.id")

		collection.UpdateRule = types.Pointer("user.id = @request.auth.id")

		collection.DeleteRule = types.Pointer("user.id = @request.auth.id")

		return dao.SaveCollection(collection)
	})
}
