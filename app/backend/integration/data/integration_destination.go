package data

import "github.com/pocketbase/pocketbase/models"

const (
	CollectionIntegrationDestination         = "integration_destination"
	IntegrationDestinationFieldDestinationId = "destination_id"
	IntegrationDestinationFieldExternalType  = "external_type"
	IntegrationDestinationFieldExternalId    = "external_id"
	IntegrationDestinationFieldUser          = "user"
)

type IntegrationDestinationType string

const (
	IntegrationDestinationTypeNotion = "notion"
)

type IntegrationDestination interface {
	Id() string
	DestinationId() string
	Type() IntegrationDestinationType
	ExternalId() string
	User() string
}

type integrationDestination struct {
	record *models.Record
}

func NewIntegrationDestination(record *models.Record) IntegrationDestination {
	return &integrationDestination{record: record}
}

func NewIntegrationDestinationFromModel(model models.Model) IntegrationDestination {
	return &integrationDestination{record: model.(*models.Record)}
}

func (i *integrationDestination) Id() string {
	return i.record.Id
}

func (i *integrationDestination) DestinationId() string {
	return i.record.GetString(IntegrationDestinationFieldDestinationId)
}

func (i *integrationDestination) Type() IntegrationDestinationType {
	return IntegrationDestinationType(i.record.GetString(IntegrationDestinationFieldExternalType))
}

func (i *integrationDestination) ExternalId() string {
	return i.record.GetString(IntegrationDestinationFieldExternalId)
}

func (i *integrationDestination) User() string {
	return i.record.GetString(IntegrationDestinationFieldUser)
}
