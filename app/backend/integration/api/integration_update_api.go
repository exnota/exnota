package api

import (
	"errors"
	"reflect"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion"
	"exnota.com/backend/lib/api"
	lib "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	integ "exnota.com/backend/integration"
)

type IntegrationUpdateAPI interface {
	ApplyHooks()
}

type integrationUpdateAPI struct {
	app         core.App
	credentials NotionCredentials
}

func NewIntegrationUpdateAPI(app core.App, credentials NotionCredentials) IntegrationUpdateAPI {
	return &integrationUpdateAPI{
		app, credentials,
	}
}

const ErrCodeInvalidNotionCode = "invalid_notion_code"

func (h *integrationUpdateAPI) ApplyHooks() {
	// Two main update update use cases:
	// 1. Update config
	// 2. Archive/unarchive
	h.app.OnRecordBeforeUpdateRequest(integ.CollectionIntegration).
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
				FindRecordById(integ.CollectionIntegration, updated.Id(), nil)
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
				if errors.Is(err, lib.ErrNotionInvalidCode) {
					return api.NewBadRequestWithErrorCode(
						ErrCodeInvalidNotionCode,
						"Invalid Notion code",
					)
				} else if err != nil {
					return err
				}

				// Ensure new botId matches existing
				if accessResponse.BotId != *existingConfig.Auth.BotID {
					return apis.NewBadRequestError("Bot ID mismatch", nil)
				}

				// Set config with notion's response
				err = updated.SetSuccessfulAuth(integ.SuccessfulNotionIntegrationAuth{
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
				updated.SetStatus(integ.IntegrationStatusConnected)
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

func configFromNotionIntegration(
	integration integ.NotionIntegration,
) (*integ.NotionIntegrationConfig, error) {
	config, err := integration.Config()
	if err != nil {
		return nil, err
	}

	return config, nil
}
