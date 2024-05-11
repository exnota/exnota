package migrations

import (
	"encoding/json"
	"log/slog"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		// up - set all workspaces to 'connected'
		dao := daos.New(db)
		query := dao.RecordQuery("workspace")

		records := []*models.Record{}
		if err := query.All(&records); err != nil {
			return err
		}

		// Loop through records
		for _, record := range records {
			if record.GetString("integration") == "" {
				continue
			}

			err := setExternalStatus(record, "connected")
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
		query := dao.RecordQuery("workspace")

		records := []*models.Record{}
		if err := query.All(&records); err != nil {
			return err
		}

		// Loop through records
		for _, record := range records {
			if record.GetString("integration") == "" {
				continue
			}

			err := setExternalStatus(record, "")
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

// The code below this comment was pulled from workspace.go and modified so that
// it compiles, as part of decoupling migrations from the main codebase.
//
// It's untested and may not work as expected, but if there are any issues they
// should be caught on the next deploy to production, which should be before we
// have any users.

type WorkspaceExternal struct {
	Status string
}

func setExternalStatus(record *models.Record, status string) error {
	// Update 'external' field
	external, err := getExternal(record)
	if err != nil {
		return err
	}
	if external == nil {
		external = &WorkspaceExternal{}
	}
	external.Status = status

	// Save
	configBytes, err := json.Marshal(external)
	if err != nil {
		slog.Error("Error marshalling workspace external field", "err", err, "id", record.Id)
		return err
	}
	record.Set("external", string(configBytes))
	return nil
}

func getExternal(record *models.Record) (*WorkspaceExternal, error) {
	// Detect if nil.
	//
	// Cannot simply use UnmarshalJSONField because if the field is nil, it will
	// throw an error even though nil is a valid value.
	raw := record.Get("external").(types.JsonRaw)
	val, err := raw.Value()
	if err != nil {
		return nil, err
	}
	// The Admin UI sends "null". To make comparisons easier, treat this the
	// same as nil.
	if val == nil || val == "null" {
		return nil, nil
	}

	// Unmarshal
	var external WorkspaceExternal
	err = record.UnmarshalJSONField("external", &external)
	if err != nil {
		return nil, err
	}
	return &external, err
}
