package notion

import (
	"errors"
	"fmt"
	"log/slog"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion/api"
	lib_integ "exnota.com/backend/lib/integration"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/pocketbase/core"
)

const titlePropertyId = "title"

type NotionExporter interface {
	Export(request NoteRequest) (*ExportResult, error)
}

type notionExporter struct {
	app                           core.App
	integrationDestinationFetcher integ.IntegrationDestinationFetcher
}

func NewNotionExporter(
	app core.App,
	integrationDestinationFetcher integ.IntegrationDestinationFetcher,
) NotionExporter {
	return &notionExporter{app, integrationDestinationFetcher}
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
	Integration integ.NotionIntegration `validate:"required"`
	Command     ExportCommand           `validate:"required"`

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
	Message      string                    `json:"message"`
	ConfigUpdate *integ.BlockMappingConfig `json:"configUpdate,omitempty" mapstructure:",omitempty"`
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

	updater, err := NewUpdater(integ.BlockMappingConfig{}, request.Id, s.app)
	if err != nil {
		return nil, err
	}

	// Handle title.
	//
	// This may be available on create when the export job was created later due
	// to the block being given a destination after creation.
	err = updater.UpdateTitle(request)
	if err != nil {
		return nil, err
	}

	// Handle file
	err = updater.UpdateFile(request)
	if err != nil {
		return nil, err
	}

	// Handle audio field (transcription)
	//
	// This may be available on create when the export job was created later due
	// to the block being given a destination after creation.
	err = updater.UpdateAudio(request)
	if err != nil {
		return nil, err
	}

	// Prepare Notion writer
	config, err := request.Integration.Config()
	if err != nil {
		return nil, err
	}
	writer := api.NewNotionWriter(s.app, *config.Auth.AccessToken)

	// Gather children
	children := []gonotion.Block{}
	children = append(children, *updater.File.ChildToInsert)
	children = append(children, updater.AudioTranscription.ChildrenToInsert...)

	// Create page in Notion
	switch destinationObject.Type() {
	case lib_integ.NotionObjectTypeDatabase:
		databaseId := destinationObject.ExternalID()
		props := updater.GenerateProperties()
		result, err := writer.CreateDatabasePage(api.CreateDatabasePageRequest{
			DatabaseId:         databaseId,
			DatabaseProperties: &props,
			Children:           children,
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
			BlockType:           integ.BlockTypeVoiceNote,
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
	case lib_integ.NotionObjectTypePage:
		parentId := destinationObject.ExternalID()
		props := updater.GenerateProperties()
		var title []gonotion.RichText
		if props != nil {
			if titleProp, ok := props[titlePropertyId]; ok {
				title = titleProp.Title
			}
		}
		result, err := writer.CreateChildPage(api.CreateChildPageRequest{
			ParentId: parentId,
			Title:    title,
			Children: children,
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
			BlockType:           integ.BlockTypeVoiceNote,
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
	previousMappingConfig, err := mapping.Config()
	if err != nil {
		return nil, err
	}
	updater, err := NewUpdater(*previousMappingConfig, mapping.ExternalBlock(), s.app)
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

	// Get and export properties
	props := updater.GenerateProperties()
	writer := api.NewNotionWriter(s.app, *integrationConfig.Auth.AccessToken)
	if len(props) != 0 {
		err = writer.UpdatePageProperties(api.UpdatePagePropertiesRequest{
			PageId:             mapping.ExternalBlock(),
			DatabaseProperties: props,
		})
		if err != nil {
			// Return without updating mappings, because no changes have actually
			// been exported to Notion.

			slog.Warn("Failed to update page properties", "err", err, "blockId", request.Id)
			return nil, err
		}
	}

	// Get and export children
	children := updater.AudioTranscription.ChildrenToInsert
	afterId := updater.AudioTranscription.InsertChildrenAfterId
	var appendChildrenErr error
	if len(children) > 0 {
		var appendResp *api.AppendPageChildrenResponse
		appendResp, appendChildrenErr = writer.AppendPageChildren(api.AppendPageChildrenRequest{
			PageId:   mapping.ExternalBlock(),
			Children: children,
			AfterId:  afterId,
		})
		if appendChildrenErr != nil {
			slog.Error(
				"Failed to append page children",
				"err",
				appendChildrenErr,
				"pageId",
				mapping.ExternalBlock(),
				"blockId",
				request.Id,
			)
			// Clear mappings that didn't take place
			updater.ResetAudioMappings()
		} else {
			// Update audio block mappings
			err = updater.SetAudioSuccess(appendResp.Children)
			if err != nil {
				slog.Error("Failed to set audio success", "err", err)
				return nil, err
			}
		}
	}

	// Save mappings. Even if children failed to append, the properties may
	// have been updated.
	updatedMappingConfig := updater.GenerateConfig()
	mappingWriter := data.NewIntegrationBlockNotionMappingWriter(s.app)
	err = mappingWriter.Update(data.UpdateMappingRequest{
		InternalBlock: request.Id,
		Config:        updatedMappingConfig,
	})
	if err != nil {
		slog.Error("Failed to update mapping", "err", err)
		return nil, errors.Join(appendChildrenErr, err)
	}

	// Note: If the job completes a partial mapping on the first attempt, on the
	// second attempt the diff will only show the latest changes and not the
	// change that was part of the first attempt.
	configUpdateDiff := updater.GenerateConfigDiff()
	return &ExportResult{
			Message:      "Updated page",
			ConfigUpdate: configUpdateDiff,
		},
		// Return the append children error so the job can be retried
		appendChildrenErr
}

func (s *notionExporter) getNotionObjectInternalId(destinationId string) (string, error) {
	integrationDestination, err := s.integrationDestinationFetcher.FetchByDestinationID(
		destinationId,
	)
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
