package data

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionIntegrationNotionObject = "integration_notion_object"

	// Id (system)
	IntegrationNotionObjectFieldExternalId = "external_id"
	IntegrationNotionObjectFieldType       = "type"
	IntegrationNotionObjectFieldStatus     = "status"
	IntegrationNotionObjectFieldProperties = "properties"
	IntegrationNotionObjectFieldLastSynced = "last_synced"
	IntegrationNotionObjectFieldUser       = "user"
	// created (system)
	// updated (system)
)

type IntegrationNotionObjectType string

const (
	IntegrationNotionObjectTypePage     IntegrationNotionObjectType = "page"
	IntegrationNotionObjectTypeDatabase IntegrationNotionObjectType = "database"
	IntegrationNotionObjectTypeBlock    IntegrationNotionObjectType = "block"
)

type IntegrationNotionObjectStatus string

const (
	IntegrationNotionObjectStatusConnected IntegrationNotionObjectStatus = "connected"
	// This can mean access was revoked or the object was deleted.
	IntegrationNotionObjectStatusNotFound     IntegrationNotionObjectStatus = "not-found"
	IntegrationNotionObjectStatusArchived     IntegrationNotionObjectStatus = "archived"
	IntegrationNotionObjectStatusUnknownError IntegrationNotionObjectStatus = "unknown-error"
	IntegrationNotionObjectStatusRateLimited  IntegrationNotionObjectStatus = "rate-limited"
)

type IntegrationNotionObject interface {
	Id() string
	ExternalId() string
	Type() IntegrationNotionObjectType
	Status() IntegrationNotionObjectStatus
	DatabaseTitlePropertyId() (string, error)
	LastSynced() time.Time
	User() string

	SetStatus(status IntegrationNotionObjectStatus)
	SetLastSynced(time.Time)
	SetProperties(any)

	ValidateAndSubmit(txDao *daos.Dao) error
}

type integrationNotionObject struct {
	record *models.Record
	app    core.App
}

func LoadIntegrationNotionObject(record *models.Record, app core.App) IntegrationNotionObject {
	return &integrationNotionObject{record, app}
}

func LoadIntegrationNotionObjectFromModel(model models.Model) IntegrationNotionObject {
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

func (i *integrationNotionObject) Status() IntegrationNotionObjectStatus {
	return IntegrationNotionObjectStatus(i.record.GetString(IntegrationNotionObjectFieldStatus))
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

func (i *integrationNotionObject) LastSynced() time.Time {
	return i.record.GetDateTime(IntegrationNotionObjectFieldLastSynced).Time()
}

func (i *integrationNotionObject) User() string {
	return i.record.GetString(IntegrationNotionObjectFieldUser)
}

func (i *integrationNotionObject) SetStatus(status IntegrationNotionObjectStatus) {
	i.record.Set(IntegrationNotionObjectFieldStatus, string(status))
}

func (i *integrationNotionObject) SetLastSynced(t time.Time) {
	i.record.Set(IntegrationNotionObjectFieldLastSynced, t)
}

func (i *integrationNotionObject) SetProperties(props any) {
	propsStr, err := json.Marshal(props)
	if err != nil {
		slog.Error("failed to marshal properties", "err", err)
		return
	}

	i.record.Set(IntegrationNotionObjectFieldProperties, string(propsStr))
}

func (i *integrationNotionObject) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(i.app, i.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}
