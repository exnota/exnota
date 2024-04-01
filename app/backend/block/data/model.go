package data

import (
	"errors"

	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionWorkspace       = "workspace"
	WorkspaceFieldName        = "name"
	WorkspaceFieldType        = "type"
	WorkspaceFieldIntegration = "integration"
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
	Type() WorkspaceType
	User() string
}

type workspace struct {
	record *models.Record
}

func NewWorkspace(model models.Model) (Workspace, error) {
	record, ok := model.(*models.Record)
	if !ok {
		return nil, errors.New("invalid model")
	}

	return &workspace{record: record}, nil
}

func (w *workspace) Id() string {
	return w.record.Id
}

func (w *workspace) Integration() string {
	return w.record.GetString(WorkspaceFieldIntegration)
}

func (w *workspace) Type() WorkspaceType {
	return WorkspaceType(w.record.GetString(WorkspaceFieldType))
}

func (w *workspace) User() string {
	return w.record.GetString(WorkspaceFieldUser)
}
