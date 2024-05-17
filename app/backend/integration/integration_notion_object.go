package integration

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	lib_integ "exnota.com/backend/lib/integration"
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
	IntegrationNotionObjectFieldTitle      = "title"
	IntegrationNotionObjectFieldProperties = "properties"
	IntegrationNotionObjectFieldLastSynced = "last_synced"
	IntegrationNotionObjectFieldUser       = "user"
	// created (system)
	// updated (system)
)

type IntegrationNotionObject interface {
	ID() string
	ExternalID() string
	Type() lib_integ.NotionObjectType
	Status() lib_integ.NotionObjectStatus
	Title() string
	DatabaseTitlePropertyID() (string, error)
	LastSynced() time.Time
	User() string

	SetStatus(status lib_integ.NotionObjectStatus)
	SetTitle(status string)
	SetProperties(any)
	SetLastSynced(time.Time)

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

func (i *integrationNotionObject) ID() string {
	return i.record.Id
}

func (i *integrationNotionObject) ExternalID() string {
	return i.record.GetString(IntegrationNotionObjectFieldExternalId)
}

func (i *integrationNotionObject) Type() lib_integ.NotionObjectType {
	return lib_integ.NotionObjectType(i.record.GetString(IntegrationNotionObjectFieldType))
}

func (i *integrationNotionObject) Status() lib_integ.NotionObjectStatus {
	return lib_integ.NotionObjectStatus(i.record.GetString(IntegrationNotionObjectFieldStatus))
}

func (i *integrationNotionObject) Title() string {
	return i.record.GetString(IntegrationNotionObjectFieldTitle)
}

func (i *integrationNotionObject) DatabaseTitlePropertyID() (string, error) {
	if i.Type() != lib_integ.NotionObjectTypeDatabase {
		slog.Error("object is not a database", "id", i.ID())
		return "", fmt.Errorf("object id %s is not a database", i.ID())
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

	slog.Error("title property not found for notion object", "id", i.ID())
	return "", fmt.Errorf("title property not found for notion object %s", i.ID())
}

func (i *integrationNotionObject) LastSynced() time.Time {
	return i.record.GetDateTime(IntegrationNotionObjectFieldLastSynced).Time()
}

func (i *integrationNotionObject) User() string {
	return i.record.GetString(IntegrationNotionObjectFieldUser)
}

func (i *integrationNotionObject) SetStatus(status lib_integ.NotionObjectStatus) {
	i.record.Set(IntegrationNotionObjectFieldStatus, string(status))
}

func (i *integrationNotionObject) SetTitle(title string) {
	i.record.Set(IntegrationNotionObjectFieldTitle, title)
}

func (i *integrationNotionObject) SetProperties(props any) {
	propsStr, err := json.Marshal(props)
	if err != nil {
		slog.Error("failed to marshal properties", "err", err)
		return
	}

	i.record.Set(IntegrationNotionObjectFieldProperties, string(propsStr))
}

func (i *integrationNotionObject) SetLastSynced(t time.Time) {
	i.record.Set(IntegrationNotionObjectFieldLastSynced, t)
}

func (i *integrationNotionObject) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(i.app, i.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}
