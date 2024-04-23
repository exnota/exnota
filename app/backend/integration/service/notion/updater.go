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
		// Original mapping, used for resetting
		InitialMappings []data.NotionMapping
		// Latest mappings (same as initial until changed)
		UpdatedMappings       []data.NotionMapping
		ChildrenToInsert      []gonotion.Block
		InsertChildrenAfterId *string
	}
	File struct {
		// File is not expected to be updated
		Mapping       *data.NotionMapping
		ChildToInsert *gonotion.AudioBlock
	}
	Title struct {
		InitialMapping   *data.NotionMapping
		UpdatedMapping   *data.NotionMapping
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

	// Save current file mapping to struct
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

	// Save current audio mappings to struct
	if len(mappingConfig.Audio) > 1 {
		slog.Error("Multiple audio mappings are not supported yet")
		return nil, fmt.Errorf("Multiple audio mappings are not supported yet")
	}
	if len(mappingConfig.Audio) == 1 && len(mappingConfig.Audio[0].Transcription) > 0 {
		audioMapping := mappingConfig.Audio[0]
		// Confirm all transcriptions are mapped to blocks
		for _, transcriptionMapping := range audioMapping.Transcription {
			if transcriptionMapping.TargetType != data.MappingTargetTypeBlock {
				slog.Error(
					"Unexpected mapping target type",
					"targetType",
					transcriptionMapping.TargetType,
				)
				return nil, fmt.Errorf("Unexpected mapping target type")
			}
		}

		updater.AudioTranscription.InitialMappings = make(
			[]data.NotionMapping,
			len(audioMapping.Transcription),
		)
		// A quick test on go playground shows `copy` should be sufficient
		// for keeping the two slices separate.
		copy(updater.AudioTranscription.InitialMappings, audioMapping.Transcription)
	}

	// Save current title mapping to struct
	if len(mappingConfig.Title) > 1 {
		slog.Error("Multiple title mappings are not supported yet")
		return nil, fmt.Errorf("Multiple title mappings are not supported yet")
	}
	if len(mappingConfig.Title) == 1 {
		mappingCopy := mappingConfig.Title[0]
		updater.Title.InitialMapping = &mappingCopy

		// Confirm title mapping is to a property
		if updater.Title.InitialMapping.TargetType != data.MappingTargetTypeProperty {
			slog.Error(
				"Unexpected mapping target type",
				"targetType",
				updater.Title.InitialMapping.TargetType,
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

	// Ignore if there are existing mappings
	if len(u.AudioTranscription.InitialMappings) > 0 {
		slog.Warn(
			"Transcriptions already mapped.",
			"blockId",
			u.BlockId,
		)
		return nil
	}

	// Add all children
	children := []gonotion.Block{}
	newMappings := []data.NotionMapping{}
	now := time.Now()
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
	u.AudioTranscription.UpdatedMappings = newMappings

	// Get afterId from File mapping, if it exists
	var afterId *string
	if u.File.Mapping != nil {
		afterId = u.File.Mapping.ExternalBlockId
	}
	u.AudioTranscription.InsertChildrenAfterId = afterId

	return nil

}

func (u *Updater) SetAudioSuccess(externalChildBlockIds []string) error {
	if len(u.AudioTranscription.UpdatedMappings) != len(externalChildBlockIds) {
		slog.Error(
			"Mismatch between transcription mappings and external child block IDs",
			"num mappings",
			len(u.AudioTranscription.UpdatedMappings),
			"num external child block IDs",
			len(externalChildBlockIds),
			"blockId",
			u.BlockId,
		)
		return fmt.Errorf("Mismatch between transcription mappings and external child block IDs")
	}

	// Assume order is the same
	for i, childId := range externalChildBlockIds {
		u.AudioTranscription.UpdatedMappings[i].ExternalBlockId = &childId
	}

	return nil
}

func (u *Updater) ResetAudioMappings() {
	u.AudioTranscription.UpdatedMappings = make(
		[]data.NotionMapping,
		len(u.AudioTranscription.InitialMappings),
	)
	copy(u.AudioTranscription.UpdatedMappings, u.AudioTranscription.InitialMappings)
}

func (u *Updater) UpdateTitle(request NoteRequest) error {
	if request.Title == nil {
		return nil
	}

	// If no existing mapping, add title property and create mapping.
	if u.Title.InitialMapping == nil {
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
		u.Title.UpdatedMapping = &data.NotionMapping{
			TargetType:         data.MappingTargetTypeProperty,
			Status:             data.BlockMappingStatusMapped,
			ContentHash:        contentHash,
			Created:            now,
			Updated:            now,
			ExternalPropertyId: &externalPropertyId,
		}
		return nil
	}

	// If there is an existing mapping, check if the content has been updated
	contentHash, err := BlockTitleToContentHash(TitleContentHashInput{
		Title: *request.Title,
	})
	if err != nil {
		return err
	}
	if u.Title.InitialMapping.ContentHash == contentHash {
		slog.Warn("Title content hash has not changed", "blockId", u.BlockId)
		return nil
	}

	// Create property object and update mapping
	u.Title.PropertyToUpdate = &gonotion.DatabasePageProperty{
		Type:  gonotion.DBPropTypeTitle,
		Title: util.TextToRichText(*request.Title),
	}

	mappingCopy := *u.Title.InitialMapping
	u.Title.UpdatedMapping = &mappingCopy
	u.Title.UpdatedMapping.Status = data.BlockMappingStatusMapped
	u.Title.UpdatedMapping.Updated = time.Now()
	u.Title.UpdatedMapping.ContentHash = contentHash

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
		id := u.Title.UpdatedMapping.ExternalPropertyId
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
	if len(u.AudioTranscription.UpdatedMappings) > 0 {
		config.Audio = []data.AudioMapping{
			{
				Transcription: u.AudioTranscription.UpdatedMappings,
			},
		}
	} else if len(u.AudioTranscription.InitialMappings) > 0 {
		config.Audio = []data.AudioMapping{
			{
				Transcription: u.AudioTranscription.InitialMappings,
			},
		}
	}

	// Add title mapping
	if u.Title.UpdatedMapping != nil {
		config.Title = []data.NotionMapping{
			*u.Title.UpdatedMapping,
		}
	} else if u.Title.InitialMapping != nil {
		config.Title = []data.NotionMapping{
			*u.Title.InitialMapping,
		}
	}

	return config

}
