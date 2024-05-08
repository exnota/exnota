package usecase

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationSync interface {
	UpdateStatus(request UpdateStatusRequest) (success bool, err error)
	UpdateDestinationStatus(request UpdateDestinationStatusRequest) error
}

type integrationSync struct {
	app core.App
}

func NewIntegrationSync(app core.App) IntegrationSync {
	return &integrationSync{app}
}

type UpdateStatusRequest struct {
	IntegrationId string `validate:"min=1"`
	UserID        string `validate:"min=1"`
}

func (s *integrationSync) UpdateStatus(request UpdateStatusRequest) (success bool, err error) {
	err = validate.Struct(request)
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

	switch integration.Type() {
	case data.IntegrationTypeNotion:
		notionSync := notion.NewNotionSync(s.app, notion.NotionCredentials{})
		verified, err := notionSync.VerifyIntegration(notion.VerifyIntegrationRequest{
			IntegrationId: request.IntegrationId,
			UserID:        request.UserID,
		})
		if err != nil {
			return false, err
		}
		return verified, nil
	default:
		slog.Error("Unknown integration type", "type", integration.Type())
		return false, fmt.Errorf("Unknown integration type: %s", integration.Type())
	}
}

type UpdateDestinationStatusRequest struct {
	IntegrationId string `validate:"min=1"`
	UserID        string `validate:"min=1"`
}

func (s *integrationSync) UpdateDestinationStatus(request UpdateDestinationStatusRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	// TODO:
	// - Call a shared/common service to get all destinations by integration ID
	// - For each destination, re-fetch the notion object.
	// - Successful updates should, through events, update the destination object (e.g. name)
	// - Updates should also update destination.external.status (options: access, no-access, remotely-deleted)

	// TODO:
	// - Can external.config in destinations be removed before persisting on
	// success?

	return nil
}
