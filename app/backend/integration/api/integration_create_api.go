package api

import (
	"errors"

	"exnota.com/backend/integration"
	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion"
	"exnota.com/backend/lib/api"
	"exnota.com/backend/lib/data/filter"
	lib "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"

	integ "exnota.com/backend/integration"
)

type IntegrationCreateAPI interface {
	ApplyHooks()
}

type integrationCreateAPI struct {
	app         core.App
	credentials NotionCredentials
}

type NotionCredentials struct {
	ClientId string
	Secret   string
}

func NewIntegrationCreateAPI(app core.App, credentials NotionCredentials) IntegrationCreateAPI {
	return &integrationCreateAPI{
		app, credentials,
	}
}

func (h *integrationCreateAPI) ApplyHooks() {
	h.app.OnRecordBeforeCreateRequest(integration.CollectionIntegration).
		Add(func(e *core.RecordCreateEvent) error {
			// Create validation and fetch access token
			integration, err := integ.LoadIntegration(e.Record, h.app)
			if err != nil {
				return err
			}
			var notionIntegration integ.NotionIntegration
			switch i := integration.(type) {
			case integ.NotionIntegration:
				notionIntegration = i
			default:
				return apis.NewBadRequestError("Invalid integration type", nil)
			}

			if notionIntegration.Status() != integ.IntegrationStatusConnected {
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
			if errors.Is(err, lib.ErrNotionInvalidCode) {
				return api.NewBadRequestWithErrorCode(
					api.ErrCodeInvalidNotionCode,
					"Invalid Notion code",
				)
			} else if err != nil {
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
			err = notionIntegration.SetSuccessfulAuth(integ.SuccessfulNotionIntegrationAuth{
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

func (h *integrationCreateAPI) userHasNotionIntegration(
	integration integ.NotionIntegration,
) (bool, error) {
	filter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  integ.IntegrationFieldUser,
			Op:    filter.OpEquals,
			Value: integration.User(),
		},
		filter.Field{
			Name:  integ.IntegrationFieldType,
			Op:    filter.OpEquals,
			Value: integ.IntegrationTypeNotion,
		},
		filter.Field{
			Name:        integ.IntegrationFieldArchived,
			Op:          filter.OpEquals,
			ValuePreset: filter.ValuePresetNull,
		},
	)
	if err != nil {
		return false, err
	}

	existingRecord, err := h.app.Dao().FindRecordsByFilter(
		integ.CollectionIntegration, filter.Filter, "-created", 1, 0,
		filter.Params)
	if err != nil {
		return false, err
	}

	return len(existingRecord) > 0, nil
}

func castToNotionIntegration(record *models.Record, app core.App) (integ.NotionIntegration, error) {
	integration, err := integ.LoadIntegration(record, app)
	if err != nil {
		return nil, err
	}

	switch i := integration.(type) {
	case integ.NotionIntegration:
		return i, nil
	default:
		return nil, errors.New("Invalid integration type")
	}
}
