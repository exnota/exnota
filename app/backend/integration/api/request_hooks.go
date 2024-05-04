package api

import (
	"errors"
	"reflect"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service/notion"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationRequestHooks interface {
	Apply()
}

type integrationRequestHooks struct {
	app         core.App
	credentials NotionCredentials
}

type NotionCredentials struct {
	ClientId string
	Secret   string
}

func NewIntegrationRequestHooks(
	app core.App,
	credentials NotionCredentials,
) IntegrationRequestHooks {
	return &integrationRequestHooks{app: app, credentials: credentials}
}

func (h *integrationRequestHooks) Apply() {
	// Authorization is implemented using API Rules in the Admin UI:
	//   Edit Collection > API Rules > Add `user.id = @request.auth.id`
	h.preventFieldUpdates()

	h.createValidationAndFetchAccessToken()
	h.updateValidationAndRefetchAccessToken()
}

func (h *integrationRequestHooks) preventFieldUpdates() {
	h.app.OnRecordBeforeUpdateRequest(data.CollectionIntegration).
		Add(func(e *core.RecordUpdateEvent) error {
			updated, err := castToNotionIntegration(e.Record, h.app)
			if err != nil {
				return err
			}

			existingRecord, err := h.app.Dao().
				FindRecordById(data.CollectionIntegration, updated.Id(), nil)
			if err != nil {
				return err
			}
			existing, err := castToNotionIntegration(existingRecord, h.app)
			if err != nil {
				return err
			}
			if updated.Type() != existing.Type() {
				return apis.NewBadRequestError("Cannot update integration type", nil)
			}
			if updated.User() != existing.User() {
				return apis.NewBadRequestError("Cannot update integration user", nil)
			}
			if updated.Status() != existing.Status() {
				return apis.NewBadRequestError("Cannot update integration status", nil)
			}
			return nil
		})
}

func (h *integrationRequestHooks) createValidationAndFetchAccessToken() {
	h.app.OnRecordBeforeCreateRequest(data.CollectionIntegration).
		Add(func(e *core.RecordCreateEvent) error {
			integration, err := data.LoadIntegration(e.Record, h.app)
			if err != nil {
				return err
			}
			var notionIntegration data.NotionIntegration
			switch i := integration.(type) {
			case data.NotionIntegration:
				notionIntegration = i
			default:
				return apis.NewBadRequestError("Invalid integration type", nil)
			}

			if notionIntegration.Status() != data.IntegrationStatusConnected {
				return apis.NewBadRequestError("Integration status must be connected", nil)
			}
			if !notionIntegration.Archived().IsZero() {
				return apis.NewBadRequestError("Archived cannot be set on create", nil)
			}

			// Check if user has Notion integration before requesting a token
			// from Notion, otherwise Notion will invalidate the code and any
			// subsequent attempts will fail.
			userHasNotionIntegration, err := h.userHasNotionIntegration(notionIntegration)
			if err != nil {
				return err
			}
			if userHasNotionIntegration {
				return apis.NewBadRequestError("User already has a Notion integration", nil)
			}

			config, err := notionIntegration.Config()
			if err != nil {
				return err
			}
			if config.Auth.Code == nil {
				return apis.NewBadRequestError("Missing Notion OAuth code", nil)
			}

			notionSync := notion.NewNotionSync(h.app, notion.NotionCredentials{
				ClientId: h.credentials.ClientId,
				Secret:   h.credentials.Secret,
			})
			accessResponse, err := notionSync.GetAuthToken(*config.Auth.Code)
			if err != nil {
				return err
			}

			// Check if bot ID already exists
			integrationFetcher := data.NewIntegrationFetcher(h.app)
			sameBotId, err := integrationFetcher.ListByNotionBotId(accessResponse.BotId)
			if err != nil {
				return err
			}
			if len(sameBotId) > 0 {
				return apis.NewBadRequestError("Bot ID already exists", nil)
			}

			// Set config with notion's response
			err = notionIntegration.SetSuccessfulAuth(data.SuccessfulNotionIntegrationAuth{
				AccessToken:          accessResponse.AccessToken,
				BotID:                accessResponse.BotId,
				DuplicatedTemplateID: &accessResponse.DuplicatedTemplateId,
				OwnerUserId:          &accessResponse.Owner.User.Id,
				WorkspaceIcon:        accessResponse.WorkspaceIcon,
				WorkspaceID:          accessResponse.WorkspaceId,
				WorkspaceName:        accessResponse.WorkspaceName,
			})
			if err != nil {
				return err
			}

			return nil
		})
}

func (h *integrationRequestHooks) userHasNotionIntegration(
	integration data.NotionIntegration,
) (bool, error) {
	filter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  data.IntegrationFieldUser,
			Op:    filter.OpEquals,
			Value: integration.User(),
		},
		filter.Field{
			Name:  data.IntegrationFieldType,
			Op:    filter.OpEquals,
			Value: data.IntegrationTypeNotion,
		},
		filter.Field{
			Name:        data.IntegrationFieldArchived,
			Op:          filter.OpEquals,
			ValuePreset: filter.ValuePresetNull,
		},
	)
	if err != nil {
		return false, err
	}

	existingRecord, err := h.app.Dao().FindRecordsByFilter(
		data.CollectionIntegration, filter.Filter, "-created", 1, 0,
		filter.Params)
	if err != nil {
		return false, err
	}

	return len(existingRecord) > 0, nil
}

func (h *integrationRequestHooks) updateValidationAndRefetchAccessToken() {
	// Two main update update use cases:
	// 1. Update config
	// 2. Archive/unarchive
	h.app.OnRecordBeforeUpdateRequest(data.CollectionIntegration).
		Add(func(e *core.RecordUpdateEvent) error {
			updated, err := castToNotionIntegration(e.Record, h.app)
			if err != nil {
				return err
			}
			updatedConfig, err := configFromNotionIntegration(updated)
			if err != nil {
				return err
			}

			existingRecord, err := h.app.Dao().
				FindRecordById(data.CollectionIntegration, updated.Id(), nil)
			if err != nil {
				return err
			}
			existing, err := castToNotionIntegration(existingRecord, h.app)
			if err != nil {
				return err
			}
			existingConfig, err := configFromNotionIntegration(existing)
			if err != nil {
				return err
			}

			// Keep the use cases separate to simplify side effect logic
			configChanged := !reflect.DeepEqual(updatedConfig, existingConfig)
			archivedChanged := updated.Archived() != existing.Archived()
			if configChanged && archivedChanged {
				return apis.NewBadRequestError(
					"Cannot update config and archived at the same time",
					nil,
				)
			}

			// Use case 1: Update config and re-connect.
			//
			// Config only expected to change when re-authorizing
			if configChanged {
				if updatedConfig == nil {
					return apis.NewBadRequestError("Missing Notion OAuth code", nil)
				}
				if updatedConfig == existingConfig {
					return apis.NewBadRequestError("New Notion OAuth code not provided", nil)
				}

				// Send request to Notion
				notionSync := notion.NewNotionSync(h.app, notion.NotionCredentials{
					ClientId: h.credentials.ClientId,
					Secret:   h.credentials.Secret,
				})
				accessResponse, err := notionSync.GetAuthToken(*updatedConfig.Auth.Code)
				if err != nil {
					return err
				}

				// Ensure new botId matches existing
				if accessResponse.BotId != *existingConfig.Auth.BotID {
					return apis.NewBadRequestError("Bot ID mismatch", nil)
				}

				// Set config with notion's response
				err = updated.SetSuccessfulAuth(data.SuccessfulNotionIntegrationAuth{
					AccessToken:          accessResponse.AccessToken,
					BotID:                accessResponse.BotId,
					DuplicatedTemplateID: &accessResponse.DuplicatedTemplateId,
					OwnerUserId:          &accessResponse.Owner.User.Id,
					WorkspaceIcon:        accessResponse.WorkspaceIcon,
					WorkspaceID:          accessResponse.WorkspaceId,
					WorkspaceName:        accessResponse.WorkspaceName,
				})
				if err != nil {
					return err
				}
				updated.SetStatus(data.IntegrationStatusConnected)
				return nil
			}

			// Use case 2: Archive/unarchive
			// (side effects handled in workspace_updater.go)
			if archivedChanged {
				// If unarchiving, ensure botId doesn't exist
				if updated.Archived().IsZero() {
					integrationFetcher := data.NewIntegrationFetcher(h.app)
					sameBotId, err := integrationFetcher.ListByNotionBotId(
						*updatedConfig.Auth.BotID,
					)
					if err != nil {
						return err
					}
					if len(sameBotId) > 1 ||
						(len(sameBotId) == 1 && sameBotId[0].Id() != updated.Id()) {
						return apis.NewBadRequestError("Bot ID already exists", nil)
					}
				}
			}

			return nil
		})
}

func castToNotionIntegration(record *models.Record, app core.App) (data.NotionIntegration, error) {
	integration, err := data.LoadIntegration(record, app)
	if err != nil {
		return nil, err
	}

	switch i := integration.(type) {
	case data.NotionIntegration:
		return i, nil
	default:
		return nil, errors.New("Invalid integration type")
	}
}

func configFromNotionIntegration(
	integration data.NotionIntegration,
) (*data.NotionIntegrationConfig, error) {
	config, err := integration.Config()
	if err != nil {
		return nil, err
	}

	return config, nil
}
