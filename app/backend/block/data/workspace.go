package data

import (
	"encoding/json"
	"errors"
	"log/slog"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionWorkspace       = "workspace"
	WorkspaceFieldName        = "name"
	WorkspaceFieldType        = "type"
	WorkspaceFieldIntegration = "integration"
	WorkspaceFieldExternal    = "external"
	WorkspaceFieldIcon        = "icon"
	WorkspaceFieldUser        = "user"
)

type WorkspaceType string

const (
	WorkspaceTypeDatabase WorkspaceType = "database"
	WorkspaceTypeCustom   WorkspaceType = "custom"
)

type Workspace interface {
	Id() string
	Integration() string
	External() (*WorkspaceExternal, error)
	Type() WorkspaceType
	User() string

	SetExternalStatus(status WorkspaceExternalStatus) error

	ValidateAndSubmit(txDao *daos.Dao) error
}

type workspace struct {
	record *models.Record
	app    core.App
}

func LoadWorkspace(model models.Model, app core.App) (Workspace, error) {
	record, ok := model.(*models.Record)
	if !ok {
		return nil, errors.New("invalid model")
	}

	return &workspace{record: record, app: app}, nil
}

func (w *workspace) Id() string {
	return w.record.Id
}

func (w *workspace) Integration() string {
	return w.record.GetString(WorkspaceFieldIntegration)
}

type WorkspaceExternal struct {
	Status WorkspaceExternalStatus `json:"status,omitempty" validate:"omitempty,oneof=connected disconnected archived"`
}

type WorkspaceExternalStatus string

const (
	// If modifying this, update the validate tag in WorkspaceExternal struct.
	WorkspaceExternalStatusConnected    WorkspaceExternalStatus = "connected"
	WorkspaceExternalStatusDisconnected WorkspaceExternalStatus = "disconnected"
	WorkspaceExternalStatusArchived     WorkspaceExternalStatus = "archived"
)

func (w *workspace) External() (*WorkspaceExternal, error) {
	// Detect if nil.
	//
	// Cannot simply use UnmarshalJSONField because if the field is nil, it will
	// throw an error even though nil is a valid value.
	raw := w.record.Get(WorkspaceFieldExternal).(types.JsonRaw)
	val, err := raw.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return nil, nil
	}

	// Unmarshal
	var external WorkspaceExternal
	err = w.record.UnmarshalJSONField(WorkspaceFieldExternal, &external)
	if err != nil {
		return nil, err
	}
	return &external, err
}

func (w *workspace) Type() WorkspaceType {
	return WorkspaceType(w.record.GetString(WorkspaceFieldType))
}

func (w *workspace) User() string {
	return w.record.GetString(WorkspaceFieldUser)
}

func (w *workspace) SetExternalStatus(status WorkspaceExternalStatus) error {
	// Update 'external' field
	external, err := w.External()
	if err != nil {
		return err
	}
	if external == nil {
		external = &WorkspaceExternal{}
	}
	external.Status = status

	// Validate
	err = validate.Struct(external)
	if err != nil {
		return err
	}

	// Save
	configBytes, err := json.Marshal(external)
	if err != nil {
		slog.Error("Error marshalling workspace external field", "err", err, "id", w.Id())
		return err
	}
	w.record.Set(WorkspaceFieldExternal, string(configBytes))
	return nil
}

func (w *workspace) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(w.app, w.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}
