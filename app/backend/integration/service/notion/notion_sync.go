package notion

import (
	"errors"
	"log/slog"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service/notion/api"
	"github.com/pocketbase/pocketbase/core"
)

type NotionSync interface {
	VerifyIntegration(request VerifyIntegrationRequest) (bool, error)
}

func NewNotionSync(app core.App) NotionSync {
	return &notionSync{app}
}

type notionSync struct {
	app core.App
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
	integration, err := integrationFetcher.FetchById(request.IntegrationId, request.UserID)
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

	// 	// TODO: update a status on both the workspace and integration that it is not accessible
	integrationWriter := data.NewIntegrationWriter(s.app)
	if !verified {
		err = integrationWriter.SetStatus(data.SetStatusRequest{
			Id:     notionIntegration.Id(),
			UserId: notionIntegration.User(),
			Status: data.IntegrationStatusAccessRevoked,
		})
		if err != nil {
			slog.Error("Error setting status", "err", err)
			return false, err
		}
		return false, nil
	}

	err = integrationWriter.SetStatus(data.SetStatusRequest{
		Id:     notionIntegration.Id(),
		UserId: notionIntegration.User(),
		Status: data.IntegrationStatusConnected,
	})
	if err != nil {
		slog.Error("Error setting status", "err", err)
		return false, err
	}

	return true, nil

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
