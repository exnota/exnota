package data

import (
	"exnota.com/backend/lib/block"
	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionIntegrationDestination              = "integration_destination"
	IntegrationDestinationFieldDestinationId      = "destination_id"
	IntegrationDestinationFieldExternalRecordType = "external_record_type"
	IntegrationDestinationFieldExternalRecordId   = "external_record_id"
	IntegrationDestinationFieldUser               = "user"
)

type IntegrationDestinationRecordType = block.DestinationExternalRecordType

const (
	IntegrationDestinationRecordTypeNotion IntegrationDestinationRecordType = block.DestinationExternalRecordTypeNotion
)

type IntegrationDestination interface {
	Id() string
	DestinationId() string
	ExternalRecordType() IntegrationDestinationRecordType
	ExternalRecordId() string
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

func (i *integrationDestination) ExternalRecordType() IntegrationDestinationRecordType {
	return IntegrationDestinationRecordType(
		i.record.GetString(IntegrationDestinationFieldExternalRecordType),
	)
}

func (i *integrationDestination) ExternalRecordId() string {
	return i.record.GetString(IntegrationDestinationFieldExternalRecordId)
}

func (i *integrationDestination) User() string {
	return i.record.GetString(IntegrationDestinationFieldUser)
}
