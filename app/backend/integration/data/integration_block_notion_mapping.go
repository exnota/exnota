package data

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

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
}

type NotionPropertyMapping struct {
	InternalId  string    `json:"id" validate:"required"`
	ExternalId  string    `json:"externalId" validate:"required"`
	ContentHash string    `json:"contentHash" validate:"required"`
	Created     time.Time `json:"created" validate:"required"`
	Updated     time.Time `json:"updated" validate:"required"`
}

type integrationBlockNotionMapping struct {
	record *models.Record
}

func NewIntegrationBlockNotionMapping(record *models.Record) (IntegrationBlockNotionMapping, error) {
	switch record.GetString(BlockNotionMappingFieldType) {
	case string(IntegrationBlockNotionMappingTypeVoiceNote):
		return NewVoiceNoteMapping(record)
	default:
		slog.Error(
			"Unsupported integration block notion mapping type",
			"recordId",
			record.Id,
			"type",
			record.GetString(BlockNotionMappingFieldType),
		)
		return nil, fmt.Errorf("unsupported integration block notion mapping type")
	}
}

func NewIntegrationBlockNotionMappingFromModel(model models.Model) (IntegrationBlockNotionMapping, error) {
	return NewIntegrationBlockNotionMapping(model.(*models.Record))
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

// ----------------------------
// Voice note mapping
// ----------------------------

type VoiceNoteMapping interface {
	IntegrationBlockNotionMapping

	Config() (*VoiceNoteMappingConfig, error)
}

type VoiceNoteMappingConfig struct {
	Properties  []NotionPropertyMapping `json:"properties" validate:"required"`
	AudioBlocks []AudioBlockMapping     `json:"audioBlocks" validate:"required"`
}
type AudioBlockMapping struct {
	InternalBlockId string    `json:"internalBlockId" validate:"required"`
	Filename        string    `json:"filename" validate:"required"`
	ExternalBlockId string    `json:"externalBlockId" validate:"required"`
	ContentHash     string    `json:"contentHash" validate:"required"`
	Created         time.Time `json:"created" validate:"required"`
	Updated         time.Time `json:"updated" validate:"required"`
}

type voiceNoteMapping struct {
	integrationBlockNotionMapping
}

func NewVoiceNoteMapping(record *models.Record) (VoiceNoteMapping, error) {
	if record.GetString(BlockNotionMappingFieldType) != string(IntegrationBlockNotionMappingTypeVoiceNote) {
		slog.Error(
			"Not a voice note mapping",
			"recordId",
			record.Id,
			"type",
			record.GetString(BlockNotionMappingFieldType),
		)
		return nil, fmt.Errorf("not a voice note mapping")
	}

	return &voiceNoteMapping{integrationBlockNotionMapping{record: record}}, nil
}

func (v *voiceNoteMapping) Config() (*VoiceNoteMappingConfig, error) {
	var config VoiceNoteMappingConfig
	err := v.record.UnmarshalJSONField(BlockNotionMappingFieldConfig, &config)
	if err != nil {
		return nil, err
	}
	return &config, nil
}
