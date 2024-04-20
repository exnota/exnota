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

const titlePropertyId = "title"

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

	// Update page in Notion
	writer := NewNotionWriter(s.app, *integrationConfig.Auth.AccessToken)
	updatePageResp, err := writer.UpdatePage(UpdatePageRequest{
		PageId:             mapping.ExternalBlock(),
		DatabaseProperties: props,
		Children:           updater.AudioTranscription.ChildrenToInsert,
		AfterId:            updater.AudioTranscription.InsertChildrenAfterId,
	})
	if err != nil {
		slog.Warn("Failed to update page", "err", err, "blockId", request.Id)
		return nil, err
	}

	// Save audio transcription block mappings
	err = updater.SetAudioSuccess(updatePageResp.Children)
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

type Updater struct {
	app core.App

	BlockId            string
	AudioTranscription struct {
		Mappings              []data.NotionMapping
		ChildrenToInsert      []gonotion.Block
		InsertChildrenAfterId *string
	}
	File struct {
		// File is not expected to be updated
		Mapping       *data.NotionMapping
		ChildToInsert *gonotion.AudioBlock
	}
	Title struct {
		Mapping          *data.NotionMapping
		PropertyToUpdate *gonotion.DatabasePageProperty
	}
}

func NewUpdater(
	mappingConfig data.BlockMappingConfig,
	blockId string,
	app core.App,
) (*Updater, error) {
	updater := &Updater{
		app:     app,
		BlockId: blockId,
	}

	// File
	if len(mappingConfig.File) > 1 {
		slog.Error("Multiple file mappings are not supported yet", "blockId", blockId)
		return nil, fmt.Errorf("Multiple file mappings are not supported yet")
	}
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

	// Audio
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

	// Title
	if len(mappingConfig.Title) > 1 {
		slog.Error("Multiple title mappings are not supported yet")
		return nil, fmt.Errorf("Multiple title mappings are not supported yet")
	}
	if len(mappingConfig.Title) == 1 {
		updater.Title.Mapping = &mappingConfig.Title[0]

		// Confirm title mapping is to a property
		if updater.Title.Mapping.TargetType != data.MappingTargetTypeProperty {
			slog.Error(
				"Unexpected mapping target type",
				"targetType",
				updater.Title.Mapping.TargetType,
			)
			return nil, fmt.Errorf("Unexpected mapping target type")
		}
	}

	return updater, nil
}

func (u *Updater) SetFile(request NoteRequest) error {
	if request.File == nil {
		return nil
	}

	// Only support audio types for now
	if request.Type != BlockTypeVoiceNote {
		slog.Error(
			"Only audio files for voice notes are supported",
			"type",
			request.Type,
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf(
			"Only audio files for voice notes are supported. Block type was: %s",
			request.Type,
		)
	}

	// Create child block
	url := pb_file.Url(*request.File, lib_block.CollectionBlock, u.BlockId, u.app)
	u.File.ChildToInsert = &gonotion.AudioBlock{
		Type: gonotion.FileTypeExternal,
		External: &gonotion.FileExternal{
			URL: url,
		},
		Caption: util.TextToRichText(*request.File),
	}

	// Create mapping
	contentHash, err := BlockFileToContentHash(FileContentHashInput{
		Collection: lib_block.CollectionBlock,
		RecordId:   u.BlockId,
		Filename:   *request.File,
	})
	if err != nil {
		slog.Error("Failed to generate content hash", "err", err)
		return err
	}
	now := time.Now()
	u.File.Mapping = &data.NotionMapping{
		TargetType:  data.MappingTargetTypeBlock,
		Status:      data.BlockMappingStatusMapped,
		ContentHash: contentHash,
		Created:     now,
		Updated:     now,
		// ExternalBlockId should be set on success
	}

	return nil
}

func (u *Updater) SetFileSuccess(externalChildBlockIds []string) error {
	if u.File.Mapping == nil {
		return fmt.Errorf("No file mapping to set success")
	}

	if len(externalChildBlockIds) != 1 {
		slog.Error(
			"Unexpected number of external child block IDs",
			"num external child block IDs",
			len(externalChildBlockIds),
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf("Unexpected number of external child block IDs")
	}

	u.File.Mapping.ExternalBlockId = &externalChildBlockIds[0]
	return nil
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

// After writing this I've wondered: Is there a significant benefit to saving
// an errored mapping? If the export job returns after an error calling the
// Notion API, it can simply retry. If there was no mapping, it will create one
// if it succeeds. If there was a mapping, the content hash will be out of date
// and it will still call notion and update the mapping. The only benefit of an
// errored mapping, I think, would be if we want the job to complete even when
// some information has not been updated. But that's not needed for now.
// func (u *Updater) SetAudioError() {
// 	for i := range u.AudioTranscription.Mappings {
// 		u.AudioTranscription.Mappings[i].Status = data.BlockMappingStatusError
// 	}
// 	return
// }

// After writing this I've wondered: Is there a significant benefit to saving
// an errored mapping? If the export job returns after an error calling the
// Notion API, it can simply retry. If there was no mapping, it will create one
// if it succeeds. If there was a mapping, the content hash will be out of date
// and it will still call notion and update the mapping. The only benefit of an
// errored mapping, I think, would be if we want the job to complete even when
// some information has not been updated. But that's not needed for now.
func (u *Updater) UpdateTitle(request NoteRequest) error {
	if request.Title == nil {
		return nil
	}

	// If no existing mapping, add title property and create mapping.
	if u.Title.Mapping == nil {
		u.Title.PropertyToUpdate = &gonotion.DatabasePageProperty{
			Type:  gonotion.DBPropTypeTitle,
			Title: util.TextToRichText(*request.Title),
		}
		contentHash, err := BlockTitleToContentHash(TitleContentHashInput{
			Title: *request.Title,
		})
		if err != nil {
			return err
		}
		now := time.Now()
		externalPropertyId := titlePropertyId
		u.Title.Mapping = &data.NotionMapping{
			TargetType:         data.MappingTargetTypeProperty,
			Status:             data.BlockMappingStatusMapped,
			ContentHash:        contentHash,
			Created:            now,
			Updated:            now,
			ExternalPropertyId: &externalPropertyId,
		}
		return nil
	}

	// If there is an existing mapping, validate that it is in the expected
	// state:
	// - It is to a property.
	// - It is not successful.
	if u.Title.Mapping.TargetType != data.MappingTargetTypeProperty {
		slog.Error(
			"Unexpected mapping target type",
			"targetType",
			u.Title.Mapping.TargetType,
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf("Unexpected mapping target type")
	}

	if u.Title.Mapping.Status == data.BlockMappingStatusMapped {
		slog.Warn("Title has already been mapped")
		return nil
	}

	// Update mapping to successful
	u.Title.Mapping.Status = data.BlockMappingStatusMapped
	u.Title.Mapping.Updated = time.Now()

	return nil
}

// After writing this I've wondered: Is there a significant benefit to saving
// an errored mapping? If the export job returns after an error calling the
// Notion API, it can simply retry. If there was no mapping, it will create one
// if it succeeds. If there was a mapping, the content hash will be out of date
// and it will still call notion and update the mapping. The only benefit of an
// errored mapping, I think, would be if we want the job to complete even when
// some information has not been updated. But that's not needed for now.
// func (u *Updater) SetTitleError() {
// 	if u.Title.Mapping != nil {
// 		u.Title.Mapping.Status = data.BlockMappingStatusError
// 	}
// 	return
// }

func (u *Updater) GenerateProperties() gonotion.DatabasePageProperties {
	props := gonotion.DatabasePageProperties{}

	// Add title
	if u.Title.PropertyToUpdate != nil {
		id := u.Title.Mapping.ExternalPropertyId
		props[*id] = *u.Title.PropertyToUpdate
	}

	return props
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

	// Add title mapping
	if u.Title.Mapping != nil {
		config.Title = []data.NotionMapping{
			*u.Title.Mapping,
		}
	}

	return config

}
