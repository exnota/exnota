package notion

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/util"
	"exnota.com/backend/lib/block"
	gonotion "github.com/dstotijn/go-notion"
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
	SyncDestination(NotionSyncRequest) (result *block.DestinationSyncResult, record *models.Record, err error)
	VerifyIntegration(request VerifyIntegrationRequest) error
}

type notionSync struct {
	app core.App
}

func NewNotionSync(app core.App) NotionSync {
	return &notionSync{app}
}

func (s *notionSync) SyncDestination(request NotionSyncRequest) (result *block.DestinationSyncResult, record *models.Record, err error) {
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

type VerifyIntegrationRequest struct {
	IntegrationId string `validate:"min=1"`
	UserID        string `validate:"min=1"`
}

var ErrAccessRevoked = fmt.Errorf("no access")

func (s *notionSync) VerifyIntegration(request VerifyIntegrationRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	integrationFetcher := data.NewIntegrationFetcher(s.app)
	integration, err := integrationFetcher.FetchById(request.IntegrationId, request.UserID)
	if err != nil {
		return err
	}

	notionIntegration, ok := integration.(data.NotionIntegration)
	if !ok {
		slog.Error("Invalid integration type", "type", integration.Type())
		return errors.New("integration is not of type NotionIntegration")
	}

	config, err := notionIntegration.Config()
	if err != nil {
		slog.Error("Error getting notion integration config", "err", err)
		return err
	}

	// Verify access
	client := gonotion.NewClient(*config.Auth.AccessToken)
	opts := &gonotion.SearchOpts{
		Query:    "",
		PageSize: 1,
	}

	// The Notion API returns the same error whether then user revokes access in
	// Notion > Settings > My connections, or if the token is modified. This can
	// be useful for testing, as we can append a character to the token to
	// simulate a revoked token.
	//
	// If the user removes all shared pages/databases, no error will be returned
	// from the Notion API. It will just return an empty list of results.
	searchResponse, err := client.Search(context.Background(), opts)
	if err != nil {
		if errors.Unwrap(errors.Unwrap(err)) == gonotion.ErrUnauthorized {
			slog.Info("Unauthorized")
			return ErrAccessRevoked
		}
		slog.Error("Error doing verify search of notion", "err", err)
		return err
	}
	// TODO: Remove this
	slog.Info("Notion search response", "response", searchResponse)

	// 	// TODO: MOve all this into a service that can be called from a cron
	// 	// job or whatever in the future. Easier to move it now I think since
	// 	// we have to test that it works

	// 	// TODO: update a status on both the workspace and integration that it is not accessible
	// 	//   - maybe a data rule: When integration status changes, workspace status changes
	// 	// TODO: If access, get all destinations belonging to it.
	// 	// TODO: Ping them all to verify we have access
	// 	// TODO: Update their statuses to reflect the result
	// 	// TODO: Return success stastus of integration itself, ignore result of destinations

	// 	// TODO: Is this right?
	// 	// TODO: It's returning just "success"? What about {result:success}?
	// 	// ...does it work with other custom endpoints? Maybe needs to be a pointer?
	// 	//...ahh it's probably the Marshal function TODO: Fix that.
	return nil
}
