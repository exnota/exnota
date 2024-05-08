package notion

import (
	"bytes"
	b64 "encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"exnota.com/backend/integration"
	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion/api"
	"exnota.com/backend/lib/url"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type NotionSync interface {
	VerifyIntegration(request VerifyIntegrationRequest) (bool, error)
	GetAuthToken(code string) (*NotionAccessTokenResponse, error)
}

type NotionCredentials struct {
	ClientId string
	Secret   string
}

func NewNotionSync(app core.App, credentials NotionCredentials) NotionSync {
	return &notionSync{app, credentials}
}

type notionSync struct {
	app         core.App
	credentials NotionCredentials
}

type VerifyIntegrationRequest struct {
	IntegrationId string `validate:"min=1"`
	UserID        string `validate:"min=1"`
}

func (s *notionSync) VerifyIntegration(request VerifyIntegrationRequest) (bool, error) {
	err := validate.Struct(request)
	if err != nil {
		return false, err
	}

	integrationFetcher := data.NewIntegrationFetcher(s.app)
	integration, err := integrationFetcher.FetchById(data.FetchByIdRequest{
		IntegrationId: request.IntegrationId,
		UserId:        request.UserID,
	})
	if err != nil {
		return false, err
	}

	notionIntegration, ok := integration.(data.NotionIntegration)
	if !ok {
		slog.Error("Invalid integration type", "type", integration.Type())
		return false, errors.New("integration is not of type NotionIntegration")
	}

	config, err := notionIntegration.Config()
	if err != nil {
		slog.Error("Error getting notion integration config", "err", err)
		return false, err
	}

	fetcher := api.NewNotionFetcher(*config.Auth.AccessToken)
	verified, err := fetcher.VerifyAccess()
	if err != nil {
		slog.Error("Error verifying access", "err", err)
		return false, err
	}

	// Updating the integration status will trigger a workspace status update
	// via hooks.
	err = s.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		// Update integration
		integrationWriter := data.NewIntegrationWriter(s.app, txDao)
		var status data.IntegrationStatus
		if !verified {
			status = data.IntegrationStatusAccessRevoked
		} else {
			status = data.IntegrationStatusConnected
		}

		err = integrationWriter.SetStatus(data.SetStatusRequest{
			Id:     notionIntegration.Id(),
			UserId: notionIntegration.User(),
			Status: status,
		})
		if err != nil {
			slog.Error("Error setting status", "err", err)
			return err
		}

		return nil
	})

	if err != nil {
		slog.Error("Error updating status", "err", err)
		return false, err
	}

	return verified, nil

	// 	//   - maybe a data rule: When integration status changes, workspace status changes
	// 	// TODO: If access, get all destinations belonging to it.
	// 	// TODO: Ping them all to verify we have access
	// 	// TODO: Update their statuses to reflect the result
	// 	// TODO: Return success stastus of integration itself, ignore result of destinations

	// 	// TODO: Is this right?
	// 	// TODO: It's returning just "success"? What about {result:success}?
	// 	// ...does it work with other custom endpoints? Maybe needs to be a pointer?
	// 	//...ahh it's probably the Marshal function TODO: Fix that.
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

func (s *notionSync) GetAuthToken(code string) (*NotionAccessTokenResponse, error) {
	body := map[string]string{
		"grant_type":   "authorization_code",
		"code":         code,
		"redirect_uri": url.Url(integration.NotionMobileRedirectPath, s.app),
	}
	bodyMarshalled, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest(
		"POST",
		"https://api.notion.com/v1/oauth/token",
		bytes.NewBuffer(bodyMarshalled),
	)
	if err != nil {
		return nil, err
	}
	auth := b64.StdEncoding.EncodeToString(
		[]byte(s.credentials.ClientId + ":" + s.credentials.Secret),
	)
	req.Header.Set("Authorization", "Basic "+auth)
	req.Header.Set("Content-Type", "application/json")

	client := http.Client{Timeout: 10 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	if res.StatusCode != 200 {
		jsonBlob, err := io.ReadAll(res.Body)
		if err != nil {
			jsonBlob = []byte{}
			slog.Error("Failed to read response body", "error", err)
		}
		slog.Warn("Notion API returned non-200 status code",
			"status_code", res.StatusCode,
			"status", res.Status,
			"body", string(jsonBlob),
		)
		return nil, fmt.Errorf(
			"Notion API returned non-200 status code %d with body %s",
			res.StatusCode,
			string(jsonBlob),
		)
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
