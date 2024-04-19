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
		err = s.addFileMapping(config, request, result.Children, request.File, now)
		if err != nil {
			return nil, err
		}

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
		err = s.addFileMapping(config, request, result.Children, request.File, now)
		if err != nil {
			return nil, err
		}

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
	_, err = s.addTitleProperty(props, request, mappingConfig)
	if err != nil {
		return nil, err
	}

	// Handle file (updating not supported)
	if request.File != nil {
		return nil, fmt.Errorf("Updating file is not supported")
	}

	// Handle audio field (transcription)
	updater, err := NewUpdater(*mappingConfig, mapping.ExternalBlock())
	if err != nil {
		return nil, err
	}
	err = updater.UpdateAudio(request)
	if err != nil {
		return nil, err
	}

	// Create notion writer
	integrationConfig, err := request.Integration.Config()
	if err != nil {
		return nil, err
	}
	writer := NewNotionWriter(s.app, *integrationConfig.Auth.AccessToken)
	updatePageResp, err := writer.UpdatePage(UpdatePageRequest{
		PageId:             mapping.ExternalBlock(),
		DatabaseProperties: props,
		Children:           updater.AudioTranscription.ChildrenToInsert,
		AfterId:            updater.AudioTranscription.InsertChildrenAfterId,
	})
	if err != nil {
		return nil, err
	}

	err = updater.SetAudioSuccess(updatePageResp.Children)
	if err != nil {
		slog.Error("Failed to set audio success", "err", err)
	}

	mappingWriter := data.NewIntegrationBlockNotionMappingWriter(s.app)
	updatedConfig := updater.GenerateConfig()
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
	now time.Time) error {
	if file != nil {
		contentHash, err := BlockFileToContentHash(FileContentHashInput{
			Collection: lib_block.CollectionBlock,
			RecordId:   request.Id,
			Filename:   *request.File,
		})
		if err != nil {
			slog.Error("Failed to generate content hash", "err", err)
			return fmt.Errorf("Failed to generate content hash")
		}
		if len(childrenIds) != 1 {
			slog.Error(
				"Expected one child block. Skipping mapping.",
				"num",
				len(childrenIds),
			)
			config.File = []data.NotionMapping{
				{
					TargetType:  data.MappingTargetTypeBlock,
					Status:      data.BlockMappingStatusError,
					ContentHash: contentHash,
					Created:     now,
					Updated:     now,
					// No ExternalBlockId,
				},
			}
		} else {
			config.File = []data.NotionMapping{
				{
					TargetType:      data.MappingTargetTypeBlock,
					Status:          data.BlockMappingStatusMapped,
					ContentHash:     contentHash,
					Created:         now,
					Updated:         now,
					ExternalBlockId: &childrenIds[0],
				},
			}

		}
	}
	return nil
}

// Returns a mapping to be updated, or nil if either no mapping is required or
// it does not need to be changed.
func (s *notionExporter) addTitleProperty(
	props gonotion.DatabasePageProperties,
	request NoteRequest,
	mappingConfig *data.BlockMappingConfig,
) ([]data.NotionMapping, error) {
	if request.Title == nil {
		return nil, nil
	}
	title := *request.Title
	// TODO: This function I added a return type [] but did not go through and
	// make sure it's being returned correctly on every return statement
	// because I'm pretty sure I'm going to refactor and not use it anymore

	// If title not mapped, proceed
	if mappingConfig.Title == nil {
		props["title"] = gonotion.DatabasePageProperty{
			Type:  gonotion.DBPropTypeTitle,
			Title: util.TextToRichText(title),
		}
		mappingConfig.Title = nil
		return nil, nil
	}

	// Update all mappings
	if mappingConfig.Title != nil {
		for _, titleMapping := range mappingConfig.Title {
			// Only handle property mappings for now
			if titleMapping.TargetType != data.MappingTargetTypeProperty {
				return nil, fmt.Errorf(
					"Unimplemented mapping target type: %s",
					titleMapping.TargetType,
				)
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

	return nil, nil
}

// TODO: Remove
func (s *notionExporter) addTranscriptionChildren(
	blockId string,
	mappingConfig *data.BlockMappingConfig,
	request NoteRequest,
) ([]gonotion.Block, error) {
	if request.Audio == nil || len(request.Audio.Transcription) == 0 {
		return []gonotion.Block{}, nil
	}

	// Find if existing mappings were successful or not
	children := []gonotion.Block{}
	for _, audioMapping := range mappingConfig.Audio {
		// Only support one set of mapped transcriptions for now
		if len(children) > 0 {
			slog.Error("Multiple transcription mappings are not supported yet", "blockId", blockId)
			return nil, fmt.Errorf("Multiple transcription mappings are not supported yet")
		}

		// Only support cases where the number of mappings match the number of
		// requested transcriptions. This is expected to always be the case as
		// transcription blocks are added at the same time.
		if len(audioMapping.Transcription) != len(request.Audio.Transcription) {
			slog.Error(
				"Mismatch between transcription mappings and request",
				"num audioMapping transcriptions",
				len(audioMapping.Transcription),
				"num request transcriptions",
				len(request.Audio.Transcription),
				"blockId",
				blockId,
			)
			return nil, fmt.Errorf("Mismatch between transcription mappings and request")
		}

		// Only support mapping transcriptions to blocks for now.
		//
		// There should be at least one transcription in this mapping as the
		// length must match the request transcriptions (see condition above)
		// and if request transcriptions is 0, we have returned early.
		if audioMapping.Transcription[0].TargetType != data.MappingTargetTypeBlock {
			slog.Error(
				"Unexpected mapping target type",
				"targetType",
				audioMapping.Transcription[0].TargetType,
				"blockId",
				blockId,
			)
			return nil, fmt.Errorf("Unexpected mapping target type")
		}

		// Skip if all transcriptions have been successfully mapped
		successfulMappings := 0
		for _, transcriptionMapping := range audioMapping.Transcription {
			if transcriptionMapping.Status == data.BlockMappingStatusMapped {
				successfulMappings++
			}
		}
		if successfulMappings == len(request.Audio.Transcription) {
			slog.Warn(
				"All transcriptions have already been mapped." + " Skipping and not checking content hash as multiple transcription mappings are not supported yet.",
			)
			continue
		}

		// Only support cases where there are no successful mappings, rather
		// than partial. This is expected to always be the case as transcription
		// blocks are added at the same time.
		if successfulMappings > 0 {
			slog.Error(
				"Unexpected number of successful mappings",
				"num successful mappings",
				successfulMappings,
				"num request transcriptions",
				len(request.Audio.Transcription),
				"blockId",
				blockId,
			)
			return nil, fmt.Errorf("Unexpected number of successful mappings")
		}

		// At this point
		// - There are the same number of mappings as transcriptions
		// - They were all unsuccessful
		// - They are all mapped to blocks
		//
		// So add all children to the array.
		for _, transcription := range request.Audio.Transcription {
			children = append(children, gonotion.ParagraphBlock{
				RichText: util.TextToRichText(transcription),
			})
		}
	}

	if len(children) > 0 {
		return children, nil
	}

	// If there are no mappings, add all children.
	for _, transcription := range request.Audio.Transcription {
		children = append(children, gonotion.ParagraphBlock{
			RichText: util.TextToRichText(transcription),
		})
	}
	return children, nil
}

// TODO: Update this so the structure represents the current plan for how mappings
// work (i.e. there's only one mapping and its either property or block).
// This should simplify the code by a lot.
type Updater struct {
	BlockId            string
	AudioTranscription struct {
		Mappings              []data.NotionMapping
		ChildrenToInsert      []gonotion.Block
		InsertChildrenAfterId *string
	}
	File struct {
		// File is not expected to be updated
		Mapping *data.NotionMapping
	}
}

func NewUpdater(mappingConfig data.BlockMappingConfig, blockId string) (*Updater, error) {
	if len(mappingConfig.File) > 1 {
		slog.Error("Multiple file mappings are not supported yet", "blockId", blockId)
		return nil, fmt.Errorf("Multiple file mappings are not supported yet")
	}

	updater := &Updater{}
	if len(mappingConfig.File) == 1 {
		updater.File.Mapping = &mappingConfig.File[0]

		// Confirm file mapping is to a block
		if updater.File.Mapping.TargetType != data.MappingTargetTypeBlock {
			slog.Error(
				"Unexpected mapping target type",
				"targetType",
				updater.File.Mapping.TargetType,
			)
			return nil, fmt.Errorf("Unexpected mapping target type")
		}
	}

	if len(mappingConfig.Audio) > 1 {
		slog.Error("Multiple audio mappings are not supported yet")
		return nil, fmt.Errorf("Multiple audio mappings are not supported yet")
	}

	// Confirm at least one audio mapping with one transcription
	if len(mappingConfig.Audio) == 1 && len(mappingConfig.Audio[0].Transcription) > 0 {
		updater.AudioTranscription.Mappings = mappingConfig.Audio[0].Transcription

		// Confirm all transcriptions are mapped to blocks
		for _, transcriptionMapping := range updater.AudioTranscription.Mappings {
			if transcriptionMapping.TargetType != data.MappingTargetTypeBlock {
				slog.Error(
					"Unexpected mapping target type",
					"targetType",
					transcriptionMapping.TargetType,
				)
				return nil, fmt.Errorf("Unexpected mapping target type")
			}
		}
	}

	return updater, nil
}

func (u *Updater) UpdateAudio(request NoteRequest) error {
	if request.Audio == nil || len(request.Audio.Transcription) == 0 {
		return nil
	}

	// If no existing mappings, add transcription children and create mappings.
	existingMappings := u.AudioTranscription.Mappings
	now := time.Now()
	if len(existingMappings) == 0 {
		// Add all children
		children := []gonotion.Block{}
		newMappings := []data.NotionMapping{}
		for _, transcription := range request.Audio.Transcription {
			children = append(children, gonotion.ParagraphBlock{
				RichText: util.TextToRichText(transcription),
			})
			contentHash, err := BlockTitleToContentHash(TitleContentHashInput{
				Title: transcription,
			})
			if err != nil {
				return err
			}
			newMappings = append(newMappings, data.NotionMapping{
				TargetType:  data.MappingTargetTypeBlock,
				Status:      data.BlockMappingStatusMapped,
				ContentHash: contentHash,
				Created:     now,
				Updated:     now,
			})
		}

		u.AudioTranscription.ChildrenToInsert = children
		u.AudioTranscription.Mappings = newMappings

		// Get afterId from File mapping, if it exists
		var afterId *string
		if u.File.Mapping != nil {
			afterId = u.File.Mapping.ExternalBlockId
		}
		u.AudioTranscription.InsertChildrenAfterId = afterId

		return nil
	}

	// If there are existing mappings, validate that they are in the expected
	// state:
	// - The number of mappings matches the number of requested transcriptions
	// - All mappings are to blocks.
	// - Mappings have the same status: All successful or all errored.
	if len(existingMappings) != len(request.Audio.Transcription) {
		slog.Error(
			"Mismatch between transcription mappings and request",
			"num audioMapping transcriptions",
			len(existingMappings),
			"num request transcriptions",
			len(request.Audio.Transcription),
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf("Mismatch between transcription mappings and request")
	}

	if existingMappings[0].TargetType != data.MappingTargetTypeBlock {
		slog.Error(
			"Unexpected mapping target type",
			"targetType",
			existingMappings[0].TargetType,
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf("Unexpected mapping target type")
	}

	successfulMappings := 0
	for _, m := range existingMappings {
		if m.Status == data.BlockMappingStatusMapped {
			successfulMappings++
		}
	}
	if successfulMappings > 0 && successfulMappings != len(request.Audio.Transcription) {
		slog.Error(
			"Unexpected number of successful mappings",
			"num successful mappings",
			successfulMappings,
			"num request transcriptions",
			len(request.Audio.Transcription),
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf("Unexpected number of successful mappings")
	}

	// We don't support updating transcription data yet, so do nothing if all
	// successful.
	if successfulMappings == len(request.Audio.Transcription) {
		slog.Warn(
			"Transcriptions already mapped." +
				" Skipping content hash check and possible further updates.",
		)
		return nil
	}

	// At this point, there are the same number of mappings as transcriptions
	// and they are all not successful.
	//
	// Add children and update mappings by moving from unchanged to new or
	// updated, and updating status and timestamp.
	children := []gonotion.Block{}
	updatedMappings := make([]data.NotionMapping, len(request.Audio.Transcription))
	for i, transcription := range request.Audio.Transcription {
		children = append(children, gonotion.ParagraphBlock{
			RichText: util.TextToRichText(transcription),
		})

		updatedMappings[i] = existingMappings[i]
		updatedMappings[i].Status = data.BlockMappingStatusMapped
		updatedMappings[i].Updated = now
	}
	u.AudioTranscription.ChildrenToInsert = children
	u.AudioTranscription.Mappings = updatedMappings
	u.AudioTranscription.Mappings = []data.NotionMapping{}

	var afterId *string
	if u.File.Mapping != nil {
		afterId = u.File.Mapping.ExternalBlockId
	}
	u.AudioTranscription.InsertChildrenAfterId = afterId

	return nil
}

func (u *Updater) SetAudioSuccess(externalChildBlockIds []string) error {
	if len(u.AudioTranscription.Mappings) != len(externalChildBlockIds) {
		slog.Error(
			"Mismatch between transcription mappings and external child block IDs",
			"num mappings",
			len(u.AudioTranscription.Mappings),
			"num external child block IDs",
			len(externalChildBlockIds),
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf("Mismatch between transcription mappings and external child block IDs")
	}

	// Assume order is the same
	for i, childId := range externalChildBlockIds {
		u.AudioTranscription.Mappings[i].ExternalBlockId = &childId
	}

	return nil
}

func (u *Updater) GenerateConfig() *data.BlockMappingConfig {
	config := &data.BlockMappingConfig{}

	// Add file mapping
	if u.File.Mapping != nil {
		config.File = []data.NotionMapping{
			*u.File.Mapping,
		}
	}

	// Add audio mappings
	audioMappings := u.AudioTranscription.Mappings
	if len(audioMappings) > 0 {
		config.Audio = []data.AudioMapping{
			{
				Transcription: audioMappings,
			},
		}
	}

	return config

}

// TODO: SetAudioError
