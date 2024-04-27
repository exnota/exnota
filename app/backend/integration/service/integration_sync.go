package service

import (
	"errors"
	"fmt"
	"log/slog"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service/notion"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationSync interface {
	UpdateStatus(request UpdateStatusRequest) (success bool, err error)
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
	integration, err := integrationFetcher.FetchById(request.IntegrationId, request.UserID)
	if err != nil {
		return false, err
	}

	switch integration.Type() {
	case data.IntegrationTypeNotion:
		notionSync := notion.NewNotionSync(s.app)
		err = notionSync.VerifyIntegration(notion.VerifyIntegrationRequest{
			IntegrationId: request.IntegrationId,
			UserID:        request.UserID,
		})
		if errors.Is(err, notion.ErrAccessRevoked) {
			// TODO: Set integration and workspace status to "no-access"

			return false, nil
		} else if err != nil {
			return false, err
		}

		// TODO: Set integration and workspace status to "success"

		// notionIntegration, ok := integration.(data.NotionIntegration)
		// if !ok {
		// 	slog.Error("Invalid integration type", "type", integration.Type())
		// 	return c.JSON(http.StatusInternalServerError, "Invalid integration type")
		// }

		// return c.JSON(http.StatusOK, VerifyIntegrationAccessResponse{
		// 	Result: Success,
		// })
		return true, nil
	default:
		slog.Error("Unknown integration type", "type", integration.Type())
		return false, fmt.Errorf("Unknown integration type: %s", integration.Type())
	}
}
