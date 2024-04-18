package notion

import (
	"fmt"
	"log/slog"
	"time"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/util"
	lib_block "exnota.com/backend/lib/block"
	"exnota.com/backend/lib/pb_file"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/pocketbase/core"
)

type NotionExporter interface {
	NoteExporter(request NoteRequest) (*ExportResult, error)
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

func (s *notionExporter) NoteExporter(request NoteRequest) (*ExportResult, error) {
	err := validate.Struct(request)
	if err != nil {
		slog.Error("Invalid NoteExporter request", "err", err)
		return nil, err
	}

	switch request.Type {
	case BlockTypeVoiceNote:
		return s.voiceNoteExporter(request)
	default:
		return nil, fmt.Errorf("Invalid export block type: %s", request.Type)
	}
}

func (s *notionExporter) voiceNoteExporter(request NoteRequest) (*ExportResult, error) {
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

	// Create page in Notion
	config, err := request.Integration.Config()
	if err != nil {
		return nil, err
	}
	writer := NewNotionWriter(s.app, *config.Auth.AccessToken)

	// Handle title
	if request.Title != nil {
		return nil, fmt.Errorf("Title is not supported yet")
	}

	// Handle audio
	if request.Audio != nil {
		return nil, fmt.Errorf("Audio is not supported yet")
	}

	// Handle file
	children := []gonotion.Block{}
	var file gonotion.Block
	if request.File != nil {
		switch request.Type {
		case BlockTypeVoiceNote:
			file = s.createAudioBlock(*request.File, request.Id)
			children = append(children, file)
		default:
			return nil, fmt.Errorf("Invalid export block type: %s", request.Type)
		}
	}

	switch destinationObject.Type() {
	case data.IntegrationNotionObjectTypeDatabase:
		databaseId := destinationObject.ExternalId()
		result, err := writer.CreateDatabasePage(CreateDatabasePageRequest{
			DatabaseId: databaseId,
			Children:   children,
		})
		if err != nil {
			return nil, err
		}
		slog.Info("Created database page", "id", result.PageId)

		now := time.Now()
		config := &data.BlockMappingConfig{}

		// Map file
		s.addFileMapping(config, request, result.Children, request.File, now)

		// Map audio, transcription in future

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
			Children: children,
		})
		if err != nil {
			return nil, err
		}
		slog.Info("Created child page", "id", result.PageId)

		now := time.Now()

		config := &data.BlockMappingConfig{}

		// Map file
		s.addFileMapping(config, request, result.Children, request.File, now)

		// Map audio, transcription in future

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
	props := gonotion.DatabasePageProperties{}
	err = s.addTitleProperty(props, request, mappingConfig)
	if err != nil {
		return nil, err
	}

	// Handle file (not supported)
	if request.File != nil {
		return nil, fmt.Errorf("Updating file is not supported")
	}

	// Handle audio field (transcription)
	// TODO: Check if transcriptions already mapped, and only proceed if content
	// hash is different or status was not mapped. AND APPLY TO afterid as well
	transcriptionChildren := []gonotion.Block{}
	if request.Audio != nil {
		for _, transcription := range request.Audio.Transcription {
			transcriptionChildren = append(transcriptionChildren, gonotion.ParagraphBlock{
				RichText: util.TextToRichText(transcription),
			})
		}
	}

	// Get afterId for transcriptions

	var afterId *string
	if len(mappingConfig.File) > 0 {
		afterId = mappingConfig.File[0].ExternalBlockId
	}

	// Create notion writer
	config, err := request.Integration.Config()
	if err != nil {
		return nil, err
	}
	writer := NewNotionWriter(s.app, *config.Auth.AccessToken)
	_, err = writer.UpdatePage(UpdatePageRequest{
		PageId:             mapping.ExternalBlock(),
		DatabaseProperties: props,
		Children:           transcriptionChildren,
		AfterId:            afterId,
	})
	if err != nil {
		return nil, err
	}

	// - TODO: update mapping
	// - TODO: return response summary update

	return nil, nil
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

func (s *notionExporter) createAudioBlock(
	file string,
	blockId string,
) gonotion.AudioBlock {
	url := pb_file.Url(file, lib_block.CollectionBlock, blockId, s.app)
	return gonotion.AudioBlock{
		Type: gonotion.FileTypeExternal,
		External: &gonotion.FileExternal{
			URL: url,
		},
		Caption: util.TextToRichText(file),
	}
}

func (s *notionExporter) addFileMapping(
	config *data.BlockMappingConfig,
	request NoteRequest,
	childrenIds []string,
	file *string,
	now time.Time) {
	if file != nil {
		if len(childrenIds) != 1 {
			slog.Error(
				"Expected one child block. Skipping mapping.",
				"num",
				len(childrenIds),
			)
			config.File = []data.NotionMapping{
				{
					TargetType: data.MappingTargetTypeBlock,
					Status:     data.BlockMappingStatusError,
					ContentHash: util.FileContentHash(
						lib_block.CollectionBlock,
						request.Id,
						*request.File,
					),
					Created: now,
					Updated: now,
					// No ExternalBlockId,
				},
			}
		} else {
			config.File = []data.NotionMapping{
				{
					TargetType: data.MappingTargetTypeBlock,
					Status:     data.BlockMappingStatusMapped,
					ContentHash: util.FileContentHash(
						lib_block.CollectionBlock,
						request.Id,
						*request.File,
					),
					Created:         now,
					Updated:         now,
					ExternalBlockId: &childrenIds[0],
				},
			}

		}
	}
}

func (s *notionExporter) addTitleProperty(
	props gonotion.DatabasePageProperties,
	request NoteRequest,
	mappingConfig *data.BlockMappingConfig,
) error {
	if request.Title == nil {
		return nil
	}
	title := *request.Title

	// If title not mapped, proceed
	if mappingConfig.Title == nil {
		props["title"] = gonotion.DatabasePageProperty{
			Type:  gonotion.DBPropTypeTitle,
			Title: util.TextToRichText(title),
		}
		return nil
	}

	// Update all mappings
	if mappingConfig.Title != nil {
		for _, titleMapping := range mappingConfig.Title {
			// Only handle property mappings for now
			if titleMapping.TargetType != data.MappingTargetTypeProperty {
				return fmt.Errorf("Unimplemented mapping target type: %s", titleMapping.TargetType)
			}

			// Skip if already mapped and content hash has not changed
			if titleMapping.Status == data.BlockMappingStatusMapped {
				if titleMapping.ContentHash == util.ContentHash(title) {
					slog.Info("Title has already been mapped")
					continue
				}
			}

			props["title"] = gonotion.DatabasePageProperty{
				Type:  gonotion.DBPropTypeTitle,
				Title: util.TextToRichText(title),
			}
		}
	}

	return nil
}
