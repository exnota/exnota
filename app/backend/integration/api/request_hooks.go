package api

import (
	"bytes"
	b64 "encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"time"

	"exnota.com/backend/integration/data"
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
		updated, err := castToNotionIntegration(e.Record)
		if err != nil {
			return err
		}

		existingRecord, err := h.app.Dao().FindRecordById(data.CollectionIntegration, updated.Id(), nil)
		if err != nil {
			return err
		}
		existing, err := castToNotionIntegration(existingRecord)
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
		integration, err := data.NewIntegration(e.Record)
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

		response, err := h.getNotionAccessTokenResponse(notionIntegration)
		if err != nil {
			return err
		}
		err = notionIntegration.SetSuccessfulAuth(data.SuccessfulNotionIntegrationAuth{
			AccessToken:          response.AccessToken,
			BotID:                response.BotId,
			DuplicatedTemplateID: &response.DuplicatedTemplateId,
			OwnerUserId:          &response.Owner.User.Id,
			WorkspaceIcon:        response.WorkspaceIcon,
			WorkspaceID:          response.WorkspaceId,
			WorkspaceName:        response.WorkspaceName,
		})
		if err != nil {
			return err
		}

		return nil
	})
}

func (h *integrationRequestHooks) updateValidationAndRefetchAccessToken() {
	h.app.OnRecordBeforeUpdateRequest(data.CollectionIntegration).Add(func(e *core.RecordUpdateEvent) error {
		updated, err := castToNotionIntegration(e.Record)
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
		existing, err := castToNotionIntegration(existingRecord)
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

		response, err := h.getNotionAccessTokenResponse(updated)
		if err != nil {
			return err
		}
		err = updated.SetSuccessfulAuth(data.SuccessfulNotionIntegrationAuth{
			AccessToken:          response.AccessToken,
			BotID:                response.BotId,
			DuplicatedTemplateID: &response.DuplicatedTemplateId,
			OwnerUserId:          &response.Owner.User.Id,
			WorkspaceIcon:        response.WorkspaceIcon,
			WorkspaceID:          response.WorkspaceId,
			WorkspaceName:        response.WorkspaceName,
		})
		if err != nil {
			return err
		}

		return nil
	})
}

func castToNotionIntegration(record *models.Record) (data.NotionIntegration, error) {
	integration, err := data.NewIntegration(record)
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

type NotionAccessTokenResponse struct {
	AccessToken          string `json:"access_token"`
	BotId                string `json:"bot_id"`
	DuplicatedTemplateId string `json:"duplicated_template_id"`
	// From Notion docs:
	//   { "workspace": true } is returned for installations of workspace-level tokens.
	//
	// We don't expect this, so assume it's a user owner and log if not.
	Owner         *User  `json:"owner,omitempty"`
	WorkspaceIcon string `json:"workspace_icon"`
	WorkspaceId   string `json:"workspace_id"`
	WorkspaceName string `json:"workspace_name"`
}

type User struct {
	Type string `json:"type"`
	User struct {
		Id     string `json:"id"`
		Object string `json:"object"`
	}
}

func (h *integrationRequestHooks) getNotionAccessTokenResponse(integration data.NotionIntegration) (*NotionAccessTokenResponse, error) {
	config, err := integration.Config()
	if err != nil {
		return nil, err
	}

	body := map[string]string{
		"grant_type":   "authorization_code",
		"code":         *config.Auth.Code,
		"redirect_uri": "https://exnota.com/api/integration/notion/mobile-code-redirect",
	}
	bodyMarshalled, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", "https://api.notion.com/v1/oauth/token", bytes.NewBuffer(bodyMarshalled))
	if err != nil {
		return nil, err
	}
	auth := b64.StdEncoding.EncodeToString([]byte(h.credentials.ClientId + ":" + h.credentials.Secret))
	req.Header.Set("Authorization", "Basic "+auth)
	req.Header.Set("Content-Type", "application/json")

	client := http.Client{Timeout: 10 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	if res.StatusCode != 200 {
		slog.Warn("Notion API returned non-200 status code",
			"status_code", res.StatusCode,
			"status", res.Status)
		return nil, errors.New("Notion API returned non-200 status code")
	}

	defer res.Body.Close()
	jsonBlob, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	// Read the response body and use json.unmarshall to unmarshall as NotionAccessToken
	var marshalledResponse NotionAccessTokenResponse
	err = json.Unmarshal(jsonBlob, &marshalledResponse)
	if err != nil {
		return nil, err
	}
	if marshalledResponse.Owner == nil {
		slog.Warn("No owner returned from Notion API", "bot_id", marshalledResponse.BotId)
	}

	return &marshalledResponse, nil
}
