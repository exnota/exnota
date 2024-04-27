package notion

import (
	"encoding/json"
	"errors"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service/notion/api"
	"exnota.com/backend/integration/util"
	"exnota.com/backend/lib/block"
	"github.com/mitchellh/mapstructure"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type NotionDestinationSyncRequest struct {
	DestinationId string
	IntegrationId string
	Config        map[string]interface{}
	User          string
}

type NotionDestinationSyncConfig struct {
	Id     string                            `json:"id" validate:"required"`
	Object NotionDestinationSyncConfigObject `json:"object" validate:"required"`
}

type NotionDestinationSyncConfigObject string

const (
	NotionSyncConfigObjectDatabase NotionDestinationSyncConfigObject = "database"
	NotionSyncConfigObjectPage     NotionDestinationSyncConfigObject = "page"
)

type NotionDestinationSync interface {
	Sync(NotionDestinationSyncRequest) (result *block.DestinationSyncResult, record *models.Record, err error)
}

type notionDestinationSync struct {
	app core.App
}

func NewNotionDestinationSync(app core.App) NotionDestinationSync {
	return &notionDestinationSync{app}
}

func (s *notionDestinationSync) Sync(request NotionDestinationSyncRequest) (result *block.DestinationSyncResult, record *models.Record, err error) {
	var config NotionDestinationSyncConfig
	err = mapstructure.Decode(request.Config, &config)
	if err != nil {
		return nil, nil, err
	}

	accessToken, err := s.accessToken(request.IntegrationId)
	if err != nil {
		return nil, nil, err
	}

	notionFetcher := api.NewNotionFetcher(accessToken)
	switch config.Object {
	case NotionSyncConfigObjectDatabase:
		database, err := notionFetcher.FetchDatabase(config.Id)
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
		page, err := notionFetcher.FetchPage(config.Id)
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

func (s *notionDestinationSync) accessToken(integrationID string) (string, error) {
	integrationFetcher := data.NewIntegrationFetcher(s.app)
	integration, err := integrationFetcher.FetchNotionIntegration(integrationID)
	if err != nil {
		return "", err
	}

	config, err := integration.Config()
	if err != nil {
		return "", err
	}
	return *config.Auth.AccessToken, nil
}
