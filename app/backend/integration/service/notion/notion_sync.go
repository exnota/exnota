package notion

import (
	"exnota.com/backend/integration/data"
	"exnota.com/backend/lib/block"
	"github.com/mitchellh/mapstructure"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type NotionSyncRequest struct {
	DestinationId string
	IntegrationId string
	Config        map[string]interface{}
	User          string
}

type NotionSyncConfig struct {
	Id     string                 `json:"id" validate:"required"`
	Object NotionSyncConfigObject `json:"object" validate:"required"`
}

type NotionSyncConfigObject string

const (
	NotionSyncConfigObjectDatabase NotionSyncConfigObject = "database"
	NotionSyncConfigObjectPage     NotionSyncConfigObject = "page"
)

type NotionSync interface {
	Sync(NotionSyncRequest) (result *block.DestinationSyncResult, record *models.Record, err error)
}

type notionSync struct {
	app core.App
}

func NewNotionSync(app core.App) NotionSync {
	return &notionSync{app}
}

func (s *notionSync) Sync(request NotionSyncRequest) (result *block.DestinationSyncResult, record *models.Record, err error) {
	var config NotionSyncConfig
	err = mapstructure.Decode(request.Config, &config)
	if err != nil {
		return nil, nil, err
	}

	// TODO: Call Notion to get info

	objectWriter := data.NewIntegrationNotionObjectWriter(s.app)
	record, err = objectWriter.UpsertRecord(data.CreateRequest{
		ExternalId: config.Id,
		Type:       data.IntegrationNotionObjectTypePage, // TODO: update
		Properties: map[string]interface{}{},             // TODO: update
		User:       request.User,
	})
	if err != nil {
		return nil, nil, err
	}

	// TODO: Return result
	return &block.DestinationSyncResult{
		ExternalRecordId:   record.Id,
		ExternalRecordType: block.DestinationExternalRecordTypeNotion,
		DestinationId:      request.DestinationId,
		DestinationName:    "Test destination name", // TODO:
	}, record, nil
}
