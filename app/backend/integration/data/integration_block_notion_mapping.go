package data

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
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

type BlockNotionMappingType string

const (
	BlockNotionMappingTypeVoiceNote BlockNotionMappingType = "voice-note"
	BlockNotionMappingTypeTextNote  BlockNotionMappingType = "text-note"
)

type IntegrationBlockNotionMapping interface {
	Id() string
	Type() BlockNotionMappingType
	InternalBlock() string
	InternalDestination() string
	ExternalBlock() string
	ExternalDestination() string
	ExternalUrl() string

	SetInternalBlock(string)
	SetInternalDestination(string)
	SetExternalBlock(string)
	SetExternalDestination(string)
	SetExternalUrl(string)
}

type NotionPropertyMapping struct {
	InternalId  string    `json:"id"          validate:"required"`
	ExternalId  string    `json:"externalId"  validate:"required"`
	ContentHash string    `json:"contentHash" validate:"required"`
	Created     time.Time `json:"created"     validate:"required"`
	Updated     time.Time `json:"updated"     validate:"required"`
}

type integrationBlockNotionMapping struct {
	record *models.Record
	app    core.App
}

func NewIntegrationBlockNotionMapping(
	record *models.Record,
	app core.App,
) (IntegrationBlockNotionMapping, error) {
	switch record.GetString(BlockNotionMappingFieldType) {
	case string(BlockNotionMappingTypeVoiceNote):
		return NewVoiceNoteMapping(record, app)
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

func NewIntegrationBlockNotionMappingFromModel(
	model models.Model,
	app core.App,
) (IntegrationBlockNotionMapping, error) {
	return NewIntegrationBlockNotionMapping(model.(*models.Record), app)
}

func (i *integrationBlockNotionMapping) Id() string {
	return i.record.Id
}

func (i *integrationBlockNotionMapping) Type() BlockNotionMappingType {
	return BlockNotionMappingType(i.record.GetString(BlockNotionMappingFieldType))
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

func (i *integrationBlockNotionMapping) SetInternalBlock(internalBlock string) {
	i.record.Set(BlockNotionMappingFieldInternalBlock, internalBlock)
}

func (i *integrationBlockNotionMapping) SetInternalDestination(internalDestination string) {
	i.record.Set(BlockNotionMappingFieldInternalDestination, internalDestination)
}

func (i *integrationBlockNotionMapping) SetExternalBlock(externalBlock string) {
	i.record.Set(BlockNotionMappingFieldExternalBlock, externalBlock)
}

func (i *integrationBlockNotionMapping) SetExternalDestination(externalDestination string) {
	i.record.Set(BlockNotionMappingFieldExternalDestination, externalDestination)
}

func (i *integrationBlockNotionMapping) SetExternalUrl(externalUrl string) {
	i.record.Set(BlockNotionMappingFieldExternalUrl, externalUrl)
}

// ----------------------------
// Voice note mapping
// ----------------------------

type VoiceNoteMapping interface {
	IntegrationBlockNotionMapping

	Config() (*VoiceNoteMappingConfig, error)
	SetConfig(config *VoiceNoteMappingConfig) error

	ValidateAndSubmit(txDao *daos.Dao) error
}

type VoiceNoteMappingConfig struct {
	Properties  []NotionPropertyMapping `json:"properties"  validate:"required"`
	AudioBlocks []AudioBlockMapping     `json:"audioBlocks" validate:"required"`
}

type BlockMappingStatus string

const (
	BlockMappingStatusMapped  BlockMappingStatus = "mapped"
	BlockMappingStatusMissing BlockMappingStatus = "missing"
)

type BlockMapping struct {
	InternalBlockId string             `json:"internalBlockId" validate:"required"`
	Status          BlockMappingStatus `json:"status"          validate:"required"`
	ExternalBlockId string             `json:"externalBlockId" validate:"required_if=Status mapped"`
	ContentHash     string             `json:"contentHash"     validate:"required"`
	Created         time.Time          `json:"created"         validate:"required"`
	Updated         time.Time          `json:"updated"         validate:"required"`
}

type AudioBlockMapping struct {
	BlockMapping
	Filename string `json:"filename" validate:"required"`
}

type voiceNoteMapping struct {
	integrationBlockNotionMapping
}

// Creates an empty voice note mapping with the expected type
func CreateVoiceNoteMapping(app core.App) (VoiceNoteMapping, error) {
	collection, err := app.Dao().FindCollectionByNameOrId(CollectionIntegrationBlockNotionMapping)
	if err != nil {
		return nil, err
	}

	record := models.NewRecord(collection)
	record.Set(BlockNotionMappingFieldType, string(BlockNotionMappingTypeVoiceNote))
	return NewVoiceNoteMapping(record, app)
}

func NewVoiceNoteMapping(record *models.Record, app core.App) (VoiceNoteMapping, error) {
	if record.GetString(BlockNotionMappingFieldType) != string(BlockNotionMappingTypeVoiceNote) {
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
		slog.Error("Error unmarshalling config", "id", v.Id(), "error", err)
		return nil, err
	}
	return &config, nil
}

func (v *voiceNoteMapping) SetConfig(config *VoiceNoteMappingConfig) error {
	err := validate.Struct(config)
	if err != nil {
		slog.Error("Error validating config", "id", v.Id(), "error", err)
		return err
	}

	configJSON, err := json.Marshal(config)
	if err != nil {
		slog.Error("Error marshalling config", "id", v.Id(), "error", err)
		return err
	}
	v.record.Set(BlockNotionMappingFieldConfig, configJSON)
	return nil
}

func (v *voiceNoteMapping) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(v.app, v.record)
	return form.Submit()
}
