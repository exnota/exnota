package data

import (
	"encoding/json"
	"log/slog"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionIntegrationBlockNotionMapping = "integration_block_notion_mapping"

	BlockNotionMappingFieldBlockType           = "blockType"
	BlockNotionMappingFieldInternalBlock       = "internalBlock"
	BlockNotionMappingFieldInternalDestination = "internalDestination"
	BlockNotionMappingFieldExternalBlock       = "externalBlock"
	BlockNotionMappingFieldExternalDestination = "externalDestination"
	BlockNotionMappingFieldExternalUrl         = "externalUrl"
	BlockNotionMappingFieldConfig              = "config"
)

type BlockType string

const (
	BlockTypeVoiceNote BlockType = "voice-note"
	BlockTypeTextNote  BlockType = "text-note"
)

type IntegrationBlockNotionMapping interface {
	Id() string
	BlockType() BlockType
	InternalBlock() string
	InternalDestination() string
	ExternalBlock() string
	ExternalDestination() string
	ExternalUrl() string
	Config() (*BlockMappingConfig, error)

	SetBlockType(BlockType)
	SetInternalBlock(string)
	SetInternalDestination(string)
	SetExternalBlock(string)
	SetExternalDestination(string)
	SetExternalUrl(string)
	SetConfig(*BlockMappingConfig) error

	ValidateAndSubmit(txDao *daos.Dao) error
}

// mapstructure:",omitempty" is used by the export job runner when persisting
// the summary.
type BlockMappingConfig struct {
	// TODO: Which of these are NOT needed
	// Id          string // Is mapped to InternalBlockId
	Title []NotionMapping `json:"title,omitempty" mapstructure:",omitempty"`
	// Type        string // Doesn't need mapping
	// User        string // Doesn't need maping
	// Destination string // Is mapped to ExternalDestinationId
	File []NotionMapping `json:"file,omitempty"  mapstructure:",omitempty"`

	// UserCreated []NotionMapping
	// Archived    []NotionMapping

	Audio []AudioMapping `json:"audio,omitempty" mapstructure:",omitempty"`

	// UserProperties map[string][]NotionMapping `json:"user_properties,omitempty"`
}

type AudioMapping struct {
	Transcription []NotionMapping `json:"transcription,omitempty"`
}

type NotionMapping struct {
	TargetType  MappingTargetType  `json:"target_type" validate:"required"`
	Status      BlockMappingStatus `json:"status"      validate:"required"`
	ContentHash string             `json:"contentHash" validate:"required"`
	Created     time.Time          `json:"created"     validate:"required"`
	Updated     time.Time          `json:"updated"     validate:"required"`

	// Should match Type
	ExternalPropertyId *string `json:"external_property_id" validate:"required_if=Type property"`
	ExternalBlockId    *string `json:"external_block_id"    validate:"required_if=Type block"`
}

type MappingTargetType string

const (
	MappingTargetTypeProperty       MappingTargetType = "property"
	MappingTargetTypeBlock          MappingTargetType = "block"
	MappingTargetTypeChildPageTitle MappingTargetType = "child-page-title"
)

type BlockMappingStatus string

const (
	BlockMappingStatusMapped  BlockMappingStatus = "mapped"
	BlockMappingStatusError   BlockMappingStatus = "error"
	BlockMappingStatusMissing BlockMappingStatus = "missing"
)

type integrationBlockNotionMapping struct {
	record *models.Record
	app    core.App
}

func CreateIntegrationBlockNotionMapping(
	app core.App,
) (IntegrationBlockNotionMapping, error) {
	collection, err := app.Dao().FindCollectionByNameOrId(CollectionIntegrationBlockNotionMapping)
	if err != nil {
		slog.Error("Error finding collection", "error", err)
		return nil, err
	}

	record := models.NewRecord(collection)
	return &integrationBlockNotionMapping{record: record, app: app}, nil
}

func LoadIntegrationBlockNotionMapping(
	record *models.Record,
	app core.App,
) (IntegrationBlockNotionMapping, error) {
	return &integrationBlockNotionMapping{record: record, app: app}, nil
}

func LoadIntegrationBlockNotionMappingFromModel(
	model models.Model,
	app core.App,
) (IntegrationBlockNotionMapping, error) {
	return LoadIntegrationBlockNotionMapping(model.(*models.Record), app)
}

func (i *integrationBlockNotionMapping) Id() string {
	return i.record.Id
}

func (i *integrationBlockNotionMapping) BlockType() BlockType {
	return BlockType(i.record.GetString(BlockNotionMappingFieldBlockType))
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

func (i *integrationBlockNotionMapping) Config() (*BlockMappingConfig, error) {
	var config BlockMappingConfig
	err := i.record.UnmarshalJSONField(BlockNotionMappingFieldConfig, &config)
	if err != nil {
		slog.Error("Error unmarshalling config", "id", i.Id(), "error", err)
		return nil, err
	}
	return &config, nil
}

func (i *integrationBlockNotionMapping) SetBlockType(blockType BlockType) {
	i.record.Set(BlockNotionMappingFieldBlockType, string(blockType))
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

func (i *integrationBlockNotionMapping) SetConfig(config *BlockMappingConfig) error {
	err := validate.Struct(config)
	if err != nil {
		return err
	}

	configBytes, err := json.Marshal(config)
	if err != nil {
		slog.Error("Error marshalling integration block notion mapping config", "err", err)
		return err
	}
	i.record.Set(BlockNotionMappingFieldConfig, string(configBytes))
	return nil
}

func (i *integrationBlockNotionMapping) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(i.app, i.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}
