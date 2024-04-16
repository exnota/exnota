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
	Integration      data.NotionIntegration           `validate:"required"`
	BlockId          string                           `validate:"required"`
	DestinationId    string                           `validate:"required"`
	ExternalRecordId string                           `validate:"required"`
	Files            []CreateVoiceNotePageRequestFile `validate:"required"`
	// TODO: Extra validation that user is user?
	// user
}

var validate = validator.New(validator.WithRequiredStructEnabled())

func (s *notionExporter) CreateVoiceNoteExporter(request CreateVoiceNoteRequest) error {
	err := validate.Struct(request)
	if err != nil {
		slog.Error("Invalid CreateVoiceNoteExporter request", "err", err)
		return err
	}

	// Complete silently if mapping already exists, as this is a create operation
	mappingFetcher := data.NewIntegrationBlockNotionMappingFetcher(s.app)
	mapping, err := mappingFetcher.FetchByInternalBlockId(request.BlockId)
	if err != nil {
		return err
	}
	if mapping != nil {
		slog.Warn("Mapping already exists", "request.BlockId", request.BlockId)
		return nil
	}

	// Get external destination object
	objectFetcher := data.NewIntegrationNotionObjectFetcher(s.app)
	destinationObject, err := objectFetcher.FetchById(request.ExternalRecordId)
	if err != nil {
		return err
	}
	if destinationObject == nil {
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
		Parent: destinationObject,
		Files:  request.Files,
	})
	if err != nil {
		return err
	}
	if page == nil {
		slog.Error("No page created")
		return fmt.Errorf("No page created")
	}

	// TODO: Get children and map to files
	notionFetcher := NewNotionFetcher(s.app)
	pageChildren, err := notionFetcher.FetchPageChildren(page.ID, request.Integration.Id())
	if err != nil {
		// Don't fail as this isn't critical for the user
		slog.Error("Failed to fetch page children. Will map without them.", "err", err)
	}
	// TODO: Remove this
	slog.Info("Fetched page children", "num", len(pageChildren))

	return nil
}
