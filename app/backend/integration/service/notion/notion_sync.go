package notion

import (
	"encoding/json"
	"errors"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/util"
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

	notionFetcher := NewNotionFetcher(s.app)
	switch config.Object {
	case NotionSyncConfigObjectDatabase:
		database, err := notionFetcher.FetchDatabase(config.Id, request.IntegrationId)
		if err != nil {
			return nil, nil, err
		}

		props, err := json.Marshal(database.Properties)
		if err != nil {
			return nil, nil, err
		}

		objectWriter := data.NewIntegrationNotionObjectWriter(s.app)
		record, err = objectWriter.UpsertRecord(data.CreateRequest{
			ExternalId: config.Id,
			Type:       data.IntegrationNotionObjectTypeDatabase,
			Properties: props,
			User:       request.User,
		})
		if err != nil {
			return nil, nil, err
		}

		return &block.DestinationSyncResult{
			ExternalRecordId:   record.Id,
			ExternalRecordType: block.DestinationExternalRecordTypeNotion,
			DestinationId:      request.DestinationId,
			DestinationName:    util.TitleToText(database.Title),
		}, record, nil

	case NotionSyncConfigObjectPage:
		page, err := notionFetcher.FetchPage(config.Id, request.IntegrationId)
		if err != nil {
			return nil, nil, err
		}

		props, err := json.Marshal(page.Properties)
		if err != nil {
			return nil, nil, err
		}

		objectWriter := data.NewIntegrationNotionObjectWriter(s.app)
		record, err = objectWriter.UpsertRecord(data.CreateRequest{
			ExternalId: config.Id,
			Type:       data.IntegrationNotionObjectTypePage,
			Properties: props,
			User:       request.User,
		})
		if err != nil {
			return nil, nil, err
		}

		title, err := util.TitleForPage(page)
		if err != nil {
			return nil, nil, err
		}
		return &block.DestinationSyncResult{
			ExternalRecordId:   record.Id,
			ExternalRecordType: block.DestinationExternalRecordTypeNotion,
			DestinationId:      request.DestinationId,
			DestinationName:    title,
		}, record, nil
	default:
		return nil, nil, errors.New("invalid object type: " + string(config.Object))
	}
}
