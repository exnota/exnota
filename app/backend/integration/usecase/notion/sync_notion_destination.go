package notion

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion/api"
	"exnota.com/backend/integration/util"
	"exnota.com/backend/lib/block"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/mitchellh/mapstructure"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type NotionDestinationSync interface {
	CreateSync(
		CreateNotionDestinationSyncRequest,
	) (result *block.CreateDestinationSyncResult, record *models.Record, err error)
	UpdateSync(request UpdateSyncRequest) error
}

type notionDestinationSync struct {
	app           core.App
	objectFetcher data.IntegrationNotionObjectFetcher
}

func NewNotionDestinationSync(
	app core.App,
	objectFetcher data.IntegrationNotionObjectFetcher,
) NotionDestinationSync {
	return &notionDestinationSync{app, objectFetcher}
}

type CreateNotionDestinationSyncRequest struct {
	DestinationId string
	IntegrationId string
	Config        map[string]interface{}
	User          string
}

type CreateNotionDestinationSyncConfig struct {
	Id     string                            `json:"id"     validate:"required"`
	Object NotionDestinationSyncConfigObject `json:"object" validate:"required"`
}

type NotionDestinationSyncConfigObject string

const (
	NotionSyncConfigObjectDatabase NotionDestinationSyncConfigObject = "database"
	NotionSyncConfigObjectPage     NotionDestinationSyncConfigObject = "page"
)

func (s *notionDestinationSync) CreateSync(
	request CreateNotionDestinationSyncRequest,
) (result *block.CreateDestinationSyncResult, record *models.Record, err error) {
	var config CreateNotionDestinationSyncConfig
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

		return &block.CreateDestinationSyncResult{
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
		return &block.CreateDestinationSyncResult{
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

type UpdateSyncRequest struct {
	IntegrationId     string   `validate:"min=1"`
	ExternalRecordIds []string `validate:"required"`
}

func (s *notionDestinationSync) UpdateSync(request UpdateSyncRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	// TODO: Get notion object IDs
	objects, err := s.objectFetcher.ListByIds(request.ExternalRecordIds)
	if err != nil {
		return err
	}

	// TODO: Remove
	slog.Info("Notion object IDs", "num", len(objects), "ids", request.ExternalRecordIds)

	for _, obj := range objects {
		// Skip if status is connected and lastSynced is less than 1 minute ago
		if obj.Status() == data.IntegrationNotionObjectStatusConnected &&
			obj.LastSynced().After(time.Now().Add(-1*time.Minute)) {
			continue
		}

		// Create fetcher
		accessToken, err := s.accessToken(request.IntegrationId)
		if err != nil {
			return err
		}
		notionFetcher := api.NewNotionFetcher(accessToken)

		// TODO: Consider error handling. I.e. one failed request shouldn't stop
		// the others.
		switch obj.Type() {
		case data.IntegrationNotionObjectTypeDatabase:
			slog.Info("Fetching database", "id", obj.ExternalId())
			database, err := notionFetcher.FetchDatabase(obj.ExternalId())
			if err != nil {
				s.handleError(obj.ExternalId(), err)
				continue
			}
			// TODO: Remove
			slog.Info("Fetched database", "id", database.ID, "title", database.Title)
			// Process the fetched database
			// TODO: Add your code here
		case data.IntegrationNotionObjectTypePage:
			slog.Info("Fetching page", "id", obj.ExternalId())
			page, err := notionFetcher.FetchPage(obj.ExternalId())
			if err != nil {
				s.handleError(obj.ExternalId(), err)
				continue
			}
			// TODO: Remove
			slog.Info("Fetched page", "id", page.ID)
			// Process the fetched page
			// TODO: Add your code here
		default:
			slog.Error("Unsupported object type", "type", obj.Type())
			return fmt.Errorf("unsupported object type: %v", obj.Type())
		}
	}

	// TODO:
	return nil
}

func (s *notionDestinationSync) handleError(id string, err error) {
	errUnwrapped := errors.Unwrap(err)
	if apiErr, ok := errUnwrapped.(*gonotion.APIError); ok {
		sourceErr := apiErr.Unwrap()
		switch sourceErr {
		case gonotion.ErrUnauthorized:
			// TODO: Test this case
			slog.Info("Unauthorized error fetching object", "id", id)
		case gonotion.ErrObjectNotFound:
			// TODO: Test this case
			slog.Info("Object not found error fetching object", "id", id)
		case gonotion.ErrRateLimited:
			slog.Warn("Rate limited error fetching object", "id", id)
		default:
			slog.Error("Unknown error fetching object", "id", id, "error", err)
		}
	} else {
		slog.Error("Non-API error fetching object", "id", id, "error", err)
	}
}
