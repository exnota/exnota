package migrations

import (
	"log/slog"

	"exnota.com/backend/block"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		// up - set all workspaces to 'connected'
		dao := daos.New(db)
		query := dao.RecordQuery(block.CollectionWorkspace)

		records := []*models.Record{}
		if err := query.All(&records); err != nil {
			return err
		}

		// Loop through records
		for _, record := range records {
			// set individual fields
			// or bulk load with record.Load(map[string]any{...})
			workspace, err := block.LoadWorkspace(record, nil)
			if err != nil {
				return err
			}

			if workspace.Integration() == "" {
				continue
			}

			err = workspace.SetExternalStatus(block.WorkspaceExternalStatusConnected)
			if err != nil {
				return err
			}

			if err := dao.SaveRecord(record); err != nil {
				return err
			}
		}
		slog.Info("Updated workspace statuses to connected", "count", len(records))

		return nil
	}, func(db dbx.Builder) error {
		// down - set all workspace statuses as empty
		dao := daos.New(db)
		query := dao.RecordQuery(block.CollectionWorkspace)

		records := []*models.Record{}
		if err := query.All(&records); err != nil {
			return err
		}

		// Loop through records
		for _, record := range records {
			// set individual fields
			// or bulk load with record.Load(map[string]any{...})
			workspace, err := block.LoadWorkspace(record, nil)
			if err != nil {
				return err
			}

			if workspace.Integration() == "" {
				continue
			}

			err = workspace.SetExternalStatus("")
			if err != nil {
				return err
			}

			if err := dao.SaveRecord(record); err != nil {
				return err
			}
		}

		slog.Info("Cleared workspace statuses", "count", len(records))

		return nil
	})
}
