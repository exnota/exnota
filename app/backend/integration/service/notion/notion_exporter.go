package notion

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/integration/data"
	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/pocketbase/core"
)

type NotionExporter interface {
	CreateVoiceNoteExporter(request CreateVoiceNoteRequest) error
}

type notionExporter struct {
	app core.App
}

func NewNotionExporter(app core.App) NotionExporter {
	return &notionExporter{app}
}

type CreateVoiceNoteRequest struct {
	Integration data.NotionIntegration `validate:"required"`
	// internal block id
	DestinationId    string                           `validate:"required"`
	ExternalRecordId string                           `validate:"required"`
	Files            []CreateVoiceNotePageRequestFile `validate:"required"`
	// user
}

var validate = validator.New(validator.WithRequiredStructEnabled())

func (s *notionExporter) CreateVoiceNoteExporter(request CreateVoiceNoteRequest) error {
	err := validate.Struct(request)
	if err != nil {
		slog.Error("Invalid CreateVoiceNoteExporter request", "err", err)
		return err
	}

	// TODO: Check if mapping exists for internal block id
	// If it does, log an error and return nil (let job complete, maybe first attempt already succeeded)

	// Get external destination object
	objectFetcher := data.NewIntegrationNotionObjectFetcher(s.app)
	object, err := objectFetcher.FetchById(request.ExternalRecordId)
	if err != nil {
		return err
	}
	if object == nil {
		slog.Error("No notion object found", "id", request.ExternalRecordId)
		return fmt.Errorf("No notion object found: %s", request.ExternalRecordId)
	}

	// Create page in Notion
	config, err := request.Integration.Config()
	if err != nil {
		return err
	}
	writer := NewNotionWriter(s.app, *config.Auth.AccessToken)
	page, err := writer.CreateVoiceNotePage(CreateVoiceNotePageRequest{
		ParentType: object.Type(),
		ParentID:   object.ExternalId(),
		Files:      request.Files,
	})
	if err != nil {
		return err
	}
	if page == nil {
		slog.Error("No page created")
		return fmt.Errorf("No page created")
	}

	// TODO: Create mapping

	return nil
}
