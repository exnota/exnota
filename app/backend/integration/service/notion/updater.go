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
	"github.com/pocketbase/pocketbase/core"
)

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
		// Don't return an error as the job doesn't need to be retried just
		// because we don't have accurate child mappings.
		slog.Info(
			"Unexpected number of external child block IDs",
			"num external child block IDs",
			len(externalChildBlockIds),
			"blockId",
			u.BlockId,
		)
		return nil
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
