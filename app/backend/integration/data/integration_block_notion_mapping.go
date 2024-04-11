package data

import (
	"encoding/json"
	"log/slog"

	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionIntegrationBlockNotionMapping = "integration_block_notion_mapping"

	BlockNotionMappingFieldType                = "type"
	BlockNotionMappingFieldInternalBlock       = "internalBlock"
	BlockNotionMappingFieldInternalDestination = "internalDestination"
	BlockNotionMappingFieldExternalBlock       = "externalBlock"
	BlockNotionMappingFieldExternalDestination = "externalDestination"
	BlockNotionMappingFieldExternalUrl         = "externalUrl"
	BlockNotionMappingFieldConfig              = "config"
)

type IntegrationBlockNotionMappingType string

const (
	IntegrationBlockNotionMappingTypeVoiceNote IntegrationBlockNotionMappingType = "voice-note"
	IntegrationBlockNotionMappingTypeTextNote  IntegrationBlockNotionMappingType = "text-note"
)

type IntegrationBlockNotionMapping interface {
	Id() string
	Type() IntegrationBlockNotionMappingType
	InternalBlock() string
	InternalDestination() string
	ExternalBlock() string
	ExternalDestination() string
	ExternalUrl() string
	Config() (map[string]interface{}, error)
}

type integrationBlockNotionMapping struct {
	record *models.Record
}

func NewIntegrationBlockNotionMapping(record *models.Record) IntegrationBlockNotionMapping {
	return &integrationBlockNotionMapping{record: record}
}

func NewIntegrationBlockNotionMappingFromModel(model models.Model) IntegrationBlockNotionMapping {
	return &integrationBlockNotionMapping{record: model.(*models.Record)}
}

func (i *integrationBlockNotionMapping) Id() string {
	return i.record.Id
}

func (i *integrationBlockNotionMapping) Type() IntegrationBlockNotionMappingType {
	return IntegrationBlockNotionMappingType(i.record.GetString(BlockNotionMappingFieldType))
}

func (i *integrationBlockNotionMapping) InternalBlock() string {
	return i.record.GetString(BlockNotionMappingFieldInternalBlock)
}

func (i *integrationBlockNotionMapping) InternalDestination() string {
	return i.record.GetString(BlockNotionMappingFieldInternalDestination)
}

func (i *integrationBlockNotionMapping) ExternalBlock() string {
	return i.record.GetString(BlockNotionMappingFieldExternalBlock)
}

func (i *integrationBlockNotionMapping) ExternalDestination() string {
	return i.record.GetString(BlockNotionMappingFieldExternalDestination)
}

func (i *integrationBlockNotionMapping) ExternalUrl() string {
	return i.record.GetString(BlockNotionMappingFieldExternalUrl)
}

func (i *integrationBlockNotionMapping) Config() (map[string]interface{}, error) {
	str := i.record.GetString(BlockNotionMappingFieldConfig)
	if str == "" {
		return map[string]interface{}{}, nil
	}

	var config map[string]interface{}
	err := json.Unmarshal([]byte(str), &config)
	if err != nil {
		slog.Error("Error unmarshalling config", "id", i.Id(), "error", err)
		return nil, err
	}
	return config, nil

}
