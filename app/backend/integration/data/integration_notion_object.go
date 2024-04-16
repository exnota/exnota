package data

import (
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionIntegrationNotionObject = "integration_notion_object"

	// Id (system)
	IntegrationNotionObjectFieldExternalId = "external_id"
	IntegrationNotionObjectFieldType       = "type"
	IntegrationNotionObjectFieldProperties = "properties"
	IntegrationNotionObjectFieldLastSynced = "last_synced"
	IntegrationNotionObjectFieldUser       = "user"
	// created (system)
	// updated (system)
)

type IntegrationNotionObjectType string

const (
	IntegrationNotionObjectTypePage     = "page"
	IntegrationNotionObjectTypeDatabase = "database"
	IntegrationNotionObjectTypeBlock    = "block"
)

type IntegrationNotionObject interface {
	Id() string
	ExternalId() string
	Type() IntegrationNotionObjectType
	DatabaseTitlePropertyId() (string, error)
	User() string
}

type integrationNotionObject struct {
	record *models.Record
}

func NewIntegrationNotionObject(record *models.Record) IntegrationNotionObject {
	return &integrationNotionObject{record: record}
}

func NewIntegrationNotionObjectFromModel(model models.Model) IntegrationNotionObject {
	return &integrationNotionObject{record: model.(*models.Record)}
}

func (i *integrationNotionObject) Id() string {
	return i.record.Id
}

func (i *integrationNotionObject) ExternalId() string {
	return i.record.GetString(IntegrationNotionObjectFieldExternalId)
}

func (i *integrationNotionObject) Type() IntegrationNotionObjectType {
	return IntegrationNotionObjectType(i.record.GetString(IntegrationNotionObjectFieldType))
}

func (i *integrationNotionObject) DatabaseTitlePropertyId() (string, error) {
	if i.Type() != IntegrationNotionObjectTypeDatabase {
		slog.Error("object is not a database", "id", i.Id())
		return "", fmt.Errorf("object id %s is not a database", i.Id())
	}

	propsStr := i.record.GetString(IntegrationNotionObjectFieldProperties)
	var props map[string]struct {
		Id   string `json:"id"`
		Type string `json:"type"`
	}
	if err := json.Unmarshal([]byte(propsStr), &props); err != nil {
		return "", err
	}

	for _, prop := range props {
		if prop.Type == string(notion.DBPropTypeTitle) {
			return prop.Id, nil
		}
	}

	slog.Error("title property not found for notion object", "id", i.Id())
	return "", fmt.Errorf("title property not found for notion object %s", i.Id())
}

func (i *integrationNotionObject) User() string {
	return i.record.GetString(IntegrationNotionObjectFieldUser)
}
