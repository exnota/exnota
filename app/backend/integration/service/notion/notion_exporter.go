package notion

import (
	"errors"
	"fmt"
	"log/slog"

	"exnota.com/backend/integration/data"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/pocketbase/core"
)

const titlePropertyId = "title"

type NotionExporter interface {
	Export(request NoteRequest) (*ExportResult, error)
}

type notionExporter struct {
	app core.App
}

func NewNotionExporter(app core.App) NotionExporter {
	return &notionExporter{app}
}

type ExportBlockType string

const (
	BlockTypeVoiceNote ExportBlockType = "voice-note"
	BlockTypeTextNote  ExportBlockType = "text-note"
)

type AudioField struct {
	Transcription []string `json:"transcription"`
}

type ExportCommand string

const (
	CommandCreateVoiceNote  ExportCommand = "create_voice_note"
	CommandAddTranscription ExportCommand = "add_transcription"
)

type NoteRequest struct {
	Integration data.NotionIntegration `validate:"required"`
	Command     ExportCommand          `validate:"required"`

	Id          string `validate:"required"`
	Title       *string
	Type        ExportBlockType `validate:"required"`
	Destination string          `validate:"required"`
	File        *string
	Audio       *AudioField
}

// mapstructure:",omitempty" is used by the export job runner when persisting
// the summary.
type ExportResult struct {
	Message      string                   `json:"message"`
	ConfigUpdate *data.BlockMappingConfig `json:"configUpdate,omitempty" mapstructure:",omitempty"`
}

var validate = validator.New(validator.WithRequiredStructEnabled())

func (s *notionExporter) Export(request NoteRequest) (*ExportResult, error) {
	err := validate.Struct(request)
	if err != nil {
		slog.Error("Invalid NoteExporter request", "err", err)
		return nil, err
	}

	switch request.Type {
	case BlockTypeVoiceNote:
		return s.exportVoiceNote(request)
	default:
		return nil, fmt.Errorf("Invalid export block type: %s", request.Type)
	}
}

func (s *notionExporter) exportVoiceNote(request NoteRequest) (*ExportResult, error) {
	switch request.Command {
	case CommandCreateVoiceNote:
		return s.createNote(request)
	case CommandAddTranscription:
		return s.updateNote(request)
	default:
		return nil, fmt.Errorf("Invalid command: %s", request.Command)
	}
}

func (s *notionExporter) createNote(request NoteRequest) (*ExportResult, error) {
	// Complete silently if mapping already exists, as this is a create operation
	mappingFetcher := data.NewIntegrationBlockNotionMappingFetcher(s.app)
	mapping, err := mappingFetcher.FetchByInternalBlockId(request.Id)
	if err != nil {
		return nil, err
	}
	if mapping != nil {
		slog.Warn("Mapping already exists", "request.Id", request.Id)

		return &ExportResult{
			Message: "Mapping already exists",
		}, nil
	}

	// Get external destination object
	notionObjectInternalId, err := s.getNotionObjectInternalId(request.Destination)
	if err != nil {
		return nil, err
	}
	objectFetcher := data.NewIntegrationNotionObjectFetcher(s.app)
	destinationObject, err := objectFetcher.FetchById(notionObjectInternalId)
	if err != nil {
		return nil, err
	}
	if destinationObject == nil {
		slog.Error("No notion object found", "id", notionObjectInternalId)
		return nil, fmt.Errorf("No notion object found: %s", notionObjectInternalId)
	}

	// TODO: When needing to update title or other properties:
	// - check mapping to see if it the property has already been mapped to
	// - check template to see if it define a db property to map to
	// - otherwise, find the title by parsing the notion object
	// fallbackTitlePropertyId, err := destinationObject.DatabaseTitlePropertyId()
	// if err != nil {
	// 	return err
	// }

	// Handle title
	if request.Title != nil {
		return nil, fmt.Errorf("Title is not supported on page create yet")
	}

	// Handle audio
	if request.Audio != nil {
		return nil, fmt.Errorf("Audio is not supported on page create yet")
	}

	// Handle file
	updater, err := NewUpdater(data.BlockMappingConfig{}, request.Id, s.app)
	if err != nil {
		return nil, err
	}
	err = updater.SetFile(request)
	if err != nil {
		return nil, err
	}

	// Prepare Notion writer
	config, err := request.Integration.Config()
	if err != nil {
		return nil, err
	}
	writer := NewNotionWriter(s.app, *config.Auth.AccessToken)

	// Gather children
	fileChildren := []gonotion.Block{}
	fileChildren = append(fileChildren, *updater.File.ChildToInsert)

	// Create page in Notion
	switch destinationObject.Type() {
	case data.IntegrationNotionObjectTypeDatabase:
		databaseId := destinationObject.ExternalId()
		result, err := writer.CreateDatabasePage(CreateDatabasePageRequest{
			DatabaseId: databaseId,
			Children:   fileChildren,
		})
		if err != nil {
			return nil, err
		}
		slog.Info("Created database page", "id", result.PageId)

		err = updater.SetFileSuccess(result.Children)
		if err != nil {
			return nil, err
		}

		config := updater.GenerateConfig()
		mappingWriter := data.NewIntegrationBlockNotionMappingWriter(s.app)
		err = mappingWriter.Create(data.CreateMappingRequest{
			BlockType:           data.BlockTypeVoiceNote,
			InternalBlock:       request.Id,
			InternalDestination: request.Destination,
			ExternalBlock:       result.PageId,
			ExternalDestination: databaseId,
			ExternalUrl:         result.Url,
			Config:              config,
		})
		if err != nil {
			slog.Error("Failed to create mapping", "err", err)
			return nil, err
		}

		return &ExportResult{
			Message:      "Mapped to database page",
			ConfigUpdate: config,
		}, nil
	case data.IntegrationNotionObjectTypePage:
		parentId := destinationObject.ExternalId()
		result, err := writer.CreateChildPage(CreateChildPageRequest{
			ParentId: parentId,
			Children: fileChildren,
		})
		if err != nil {
			return nil, err
		}
		slog.Info("Created child page", "id", result.PageId)

		err = updater.SetFileSuccess(result.Children)
		if err != nil {
			slog.Error("Failed to set file success", "err", err)
			return nil, err
		}

		config := updater.GenerateConfig()
		mappingWriter := data.NewIntegrationBlockNotionMappingWriter(s.app)
		err = mappingWriter.Create(data.CreateMappingRequest{
			BlockType:           data.BlockTypeVoiceNote,
			InternalBlock:       request.Id,
			InternalDestination: request.Destination,
			ExternalBlock:       result.PageId,
			ExternalDestination: parentId,
			ExternalUrl:         result.Url,
			Config:              config,
		})
		if err != nil {
			slog.Error("Failed to create mapping", "err", err)
			return nil, err
		}

		return &ExportResult{
			Message:      "Mapped to child page",
			ConfigUpdate: config,
		}, nil
	}

	return nil, fmt.Errorf("Invalid destination object type: %s", destinationObject.Type())
}

func (s *notionExporter) updateNote(request NoteRequest) (*ExportResult, error) {
	// Get mapping
	mappingFetcher := data.NewIntegrationBlockNotionMappingFetcher(s.app)
	mapping, err := mappingFetcher.FetchByInternalBlockId(request.Id)
	if err != nil {
		return nil, err
	}
	if mapping == nil {
		slog.Error("Mapping does not exist for block update", "blockId", request.Id)

		return nil, fmt.Errorf("Mapping does not exist for block id %s", request.Id)
	}

	// Handle title
	mappingConfig, err := mapping.Config()
	if err != nil {
		return nil, err
	}
	updater, err := NewUpdater(*mappingConfig, mapping.ExternalBlock(), s.app)
	if err != nil {
		return nil, err
	}
	err = updater.UpdateTitle(request)
	if err != nil {
		return nil, err
	}

	// Handle file (updating not supported)
	if request.File != nil {
		return nil, fmt.Errorf("Updating file is not supported")
	}

	// Handle audio field (transcription)
	err = updater.UpdateAudio(request)
	if err != nil {
		return nil, err
	}

	// Get config for access token
	integrationConfig, err := request.Integration.Config()
	if err != nil {
		return nil, err
	}

	// Get props
	props := updater.GenerateProperties()

	// Update page properties in Notion
	writer := NewNotionWriter(s.app, *integrationConfig.Auth.AccessToken)
	err = writer.UpdatePageProperties(UpdatePagePropertiesRequest{
		PageId:             mapping.ExternalBlock(),
		DatabaseProperties: props,
	})
	if err != nil {
		// Return without updating mappings, because no changes have actually
		// been exported to Notion.

		slog.Warn("Failed to update page properties", "err", err, "blockId", request.Id)
		return nil, err
	}

	// Append page children in Notion
	appendResp, appendErr := writer.AppendPageChildren(AppendPageChildrenRequest{
		PageId:   mapping.ExternalBlock(),
		Children: updater.AudioTranscription.ChildrenToInsert,
		AfterId:  updater.AudioTranscription.InsertChildrenAfterId,
	})
	if appendErr != nil {
		slog.Error(
			"Failed to append page children",
			"err",
			appendErr,
			"pageId",
			mapping.ExternalBlock(),
			"blockId",
			request.Id,
		)

		// Clear failed append mappings
		updater.ResetAudioMappings()

		// Save successful property mappings
		updatedConfig := updater.GenerateConfig()
		mappingWriter := data.NewIntegrationBlockNotionMappingWriter(s.app)
		err = mappingWriter.Update(data.UpdateMappingRequest{
			InternalBlock: request.Id,
			Config:        updatedConfig,
		})
		if err != nil {
			slog.Error("Failed to update mapping", "err", err)
			return nil, errors.Join(appendErr, err)
		}

		// Return the error so the job can be retried
		return nil, appendErr
	} else {
		// Update audio block mappings
		err = updater.SetAudioSuccess(appendResp.Children)
		if err != nil {
			slog.Error("Failed to set audio success", "err", err)
			return nil, err
		}

		// Save mappings
		updatedConfig := updater.GenerateConfig()
		mappingWriter := data.NewIntegrationBlockNotionMappingWriter(s.app)
		err = mappingWriter.Update(data.UpdateMappingRequest{
			InternalBlock: request.Id,
			Config:        updatedConfig,
		})
		if err != nil {
			slog.Error("Failed to update mapping", "err", err)
			return nil, err
		}

		// - TODO: return response summary update. This could be returned as a diff
		// from 'updater', which just returns 'new or updated' mappings.

		return nil, nil
	}
}

func (s *notionExporter) getNotionObjectInternalId(destinationId string) (string, error) {
	integrationDestinationRepo := data.NewIntegrationDestinationFetcher(s.app)
	integrationDestination, err := integrationDestinationRepo.FetchByDestinationId(destinationId)
	if err != nil {
		slog.Error(
			"Error fetching integration destination by destination id",
			"destinationId",
			destinationId,
			"err",
			err,
		)
		return "", err
	}
	if integrationDestination == nil {
		slog.Error("Integration destination not found", "destinationId", destinationId)
		return "", fmt.Errorf("Integration destination not found")
	}

	return integrationDestination.ExternalRecordId(), nil
}
