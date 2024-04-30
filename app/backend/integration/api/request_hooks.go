package api

import (
	"errors"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service/notion"
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

func NewIntegrationRequestHooks(app core.App, credentials NotionCredentials) IntegrationRequestHooks {
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
	h.app.OnRecordBeforeUpdateRequest(data.CollectionIntegration).Add(func(e *core.RecordUpdateEvent) error {
		updated, err := castToNotionIntegration(e.Record, h.app)
		if err != nil {
			return err
		}

		existingRecord, err := h.app.Dao().FindRecordById(data.CollectionIntegration, updated.Id(), nil)
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
		return nil
	})
}

func (h *integrationRequestHooks) createValidationAndFetchAccessToken() {
	h.app.OnRecordBeforeCreateRequest(data.CollectionIntegration).Add(func(e *core.RecordCreateEvent) error {
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

func (h *integrationRequestHooks) updateValidationAndRefetchAccessToken() {
	h.app.OnRecordBeforeUpdateRequest(data.CollectionIntegration).Add(func(e *core.RecordUpdateEvent) error {
		updated, err := castToNotionIntegration(e.Record, h.app)
		if err != nil {
			return err
		}
		updatedCode, err := codeFromNotionIntegration(updated)
		if err != nil {
			return err
		}

		existingRecord, err := h.app.Dao().FindRecordById(data.CollectionIntegration, updated.Id(), nil)
		if err != nil {
			return err
		}
		existing, err := castToNotionIntegration(existingRecord, h.app)
		if err != nil {
			return err
		}
		existingCode, err := codeFromNotionIntegration(existing)
		if err != nil {
			return err
		}

		if updatedCode == nil {
			return apis.NewBadRequestError("Missing Notion OAuth code", nil)
		}
		if updatedCode == existingCode {
			return apis.NewBadRequestError("New Notion OAuth code not provided", nil)
		}

		notionSync := notion.NewNotionSync(h.app, notion.NotionCredentials{
			ClientId: h.credentials.ClientId,
			Secret:   h.credentials.Secret,
		})
		accessResponse, err := notionSync.GetAuthToken(*updatedCode)
		if err != nil {
			return err
		}
		err = updated.SetSuccessfulAuth(data.SuccessfulNotionIntegrationAuth{
			AccessToken:          accessResponse.AccessToken,
			BotID:                accessResponse.BotId,
			DuplicatedTemplateID: &accessResponse.DuplicatedTemplateId,
			OwnerUserId:          &accessResponse.Owner.User.Id,
			WorkspaceIcon:        accessResponse.WorkspaceIcon,
			WorkspaceID:          accessResponse.WorkspaceId,
			WorkspaceName:        accessResponse.WorkspaceName,
		})
		updated.SetStatus(data.IntegrationStatusConnected)
		if err != nil {
			return err
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

func codeFromNotionIntegration(integration data.NotionIntegration) (*string, error) {
	config, err := integration.Config()
	if err != nil {
		return nil, err
	}

	return config.Auth.Code, nil
}
