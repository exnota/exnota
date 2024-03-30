package api

import (
	"bytes"
	b64 "encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"time"

	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
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
	h.app.OnRecordBeforeCreateRequest(integ.CollectionIntegration).Add(func(e *core.RecordCreateEvent) error {
		integration, err := NewIntegration(e.Record)
		if err != nil {
			return err
		}

		var notionIntegration NotionIntegration
		switch i := integration.(type) {
		case NotionIntegration:
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
		err = notionIntegration.SetSuccessfulAuth(SuccessfulNotionIntegrationAuth{
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

func (h *integrationRequestHooks) getNotionAccessTokenResponse(integration NotionIntegration) (*NotionAccessTokenResponse, error) {
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
