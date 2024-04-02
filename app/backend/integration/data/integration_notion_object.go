package data

import "github.com/pocketbase/pocketbase/models"

const (
	CollectionIntegrationNotionObject      = "integration_notion_object"
	IntegrationNotionObjectFieldType       = "type"
	IntegrationNotionObjectFieldExternalId = "external_id"
	IntegrationNotionObjectFieldUser       = "user"
)

type IntegrationNotionObjectType string

const (
	IntegrationNotionObjectTypePage     = "page"
	IntegrationNotionObjectTypeDatabase = "database"
	IntegrationNotionObjectTypeBlock    = "block"
)

type IntegrationNotionObject interface {
	Id() string
	Type() IntegrationNotionObjectType
	ExternalId() string
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

func (i *integrationNotionObject) Type() IntegrationNotionObjectType {
	return IntegrationNotionObjectType(i.record.GetString(IntegrationNotionObjectFieldType))
}

func (i *integrationNotionObject) ExternalId() string {
	return i.record.GetString(IntegrationNotionObjectFieldExternalId)
}

func (i *integrationNotionObject) User() string {
	return i.record.GetString(IntegrationNotionObjectFieldUser)
}
