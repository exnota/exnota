package notion

import (
	"fmt"
	"log/slog"
	"time"

	integ "exnota.com/backend/integration"
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
		CurrentMappings []integ.NotionMapping
		// Latest mappings (same as initial until changed)
		UpdatedMappings       []integ.NotionMapping
		ChildrenToInsert      []gonotion.Block
		InsertChildrenAfterId *string
	}
	File struct {
		CurrentMapping *integ.NotionMapping
		UpdatedMapping *integ.NotionMapping
		ChildToInsert  *gonotion.AudioBlock
	}
	Title struct {
		CurrentMapping   *integ.NotionMapping
		UpdatedMapping   *integ.NotionMapping
		PropertyToUpdate *gonotion.DatabasePageProperty
	}
}

func NewUpdater(
	mappingConfig integ.BlockMappingConfig,
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
		updater.File.CurrentMapping = &mappingConfig.File[0]

		// Confirm file mapping is to a block
		if updater.File.CurrentMapping.TargetType != integ.MappingTargetTypeBlock {
			slog.Error(
				"Unexpected mapping target type",
				"targetType",
				updater.File.CurrentMapping.TargetType,
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
			if transcriptionMapping.TargetType != integ.MappingTargetTypeBlock {
				slog.Error(
					"Unexpected mapping target type",
					"targetType",
					transcriptionMapping.TargetType,
				)
				return nil, fmt.Errorf("Unexpected mapping target type")
			}
		}

		updater.AudioTranscription.CurrentMappings = make(
			[]integ.NotionMapping,
			len(audioMapping.Transcription),
		)
		// A quick test on go playground shows `copy` should be sufficient
		// for keeping the two slices separate.
		copy(updater.AudioTranscription.CurrentMappings, audioMapping.Transcription)
	}

	// Save current title mapping to struct
	if len(mappingConfig.Title) > 1 {
		slog.Error("Multiple title mappings are not supported yet")
		return nil, fmt.Errorf("Multiple title mappings are not supported yet")
	}
	if len(mappingConfig.Title) == 1 {
		mappingCopy := mappingConfig.Title[0]
		updater.Title.CurrentMapping = &mappingCopy

		// Confirm title mapping is to a property
		if updater.Title.CurrentMapping.TargetType != integ.MappingTargetTypeProperty {
			slog.Error(
				"Unexpected mapping target type",
				"targetType",
				updater.Title.CurrentMapping.TargetType,
			)
			return nil, fmt.Errorf("Unexpected mapping target type")
		}
	}

	return updater, nil
}

func (u *Updater) UpdateFile(request NoteRequest) error {
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

	// Ignore if there are existing mappings
	if u.File.UpdatedMapping != nil {
		slog.Warn(
			"File already mapped.",
			"blockId",
			u.BlockId,
		)
		return nil
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
	u.File.UpdatedMapping = &integ.NotionMapping{
		TargetType:  integ.MappingTargetTypeBlock,
		Status:      integ.BlockMappingStatusMapped,
		ContentHash: contentHash,
		Created:     now,
		Updated:     now,
		// ExternalBlockId should be set on success using [SetFileSuccess]
	}

	return nil
}

func (u *Updater) SetFileSuccess(externalChildBlockIds []string) error {
	if u.File.UpdatedMapping == nil {
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

	u.File.UpdatedMapping.ExternalBlockId = &externalChildBlockIds[0]
	return nil
}

func (u *Updater) UpdateAudio(request NoteRequest) error {
	if request.Audio == nil || len(request.Audio.Transcription) == 0 {
		return nil
	}

	// Ignore if there are existing mappings
	if len(u.AudioTranscription.CurrentMappings) > 0 {
		slog.Warn(
			"Transcriptions already mapped.",
			"blockId",
			u.BlockId,
		)
		return nil
	}

	// Add all children
	children := []gonotion.Block{}
	newMappings := []integ.NotionMapping{}
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
		newMappings = append(newMappings, integ.NotionMapping{
			TargetType:  integ.MappingTargetTypeBlock,
			Status:      integ.BlockMappingStatusMapped,
			ContentHash: contentHash,
			Created:     now,
			Updated:     now,
		})
	}

	u.AudioTranscription.ChildrenToInsert = children
	u.AudioTranscription.UpdatedMappings = newMappings

	// Get afterId from File mapping, if it exists
	var afterId *string
	if u.File.UpdatedMapping != nil {
		afterId = u.File.UpdatedMapping.ExternalBlockId
	} else if u.File.CurrentMapping != nil {
		afterId = u.File.CurrentMapping.ExternalBlockId
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
		[]integ.NotionMapping,
		len(u.AudioTranscription.CurrentMappings),
	)
	copy(u.AudioTranscription.UpdatedMappings, u.AudioTranscription.CurrentMappings)
}

func (u *Updater) UpdateTitle(request NoteRequest) error {
	if request.Title == nil {
		return nil
	}

	// If no existing mapping, add title property and create mapping.
	if u.Title.CurrentMapping == nil {
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
		u.Title.UpdatedMapping = &integ.NotionMapping{
			TargetType:         integ.MappingTargetTypeProperty,
			Status:             integ.BlockMappingStatusMapped,
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
	if u.Title.CurrentMapping.ContentHash == contentHash {
		slog.Warn("Title content hash has not changed", "blockId", u.BlockId)
		return nil
	}

	// Create property object and update mapping
	u.Title.PropertyToUpdate = &gonotion.DatabasePageProperty{
		Type:  gonotion.DBPropTypeTitle,
		Title: util.TextToRichText(*request.Title),
	}

	mappingCopy := *u.Title.CurrentMapping
	u.Title.UpdatedMapping = &mappingCopy
	u.Title.UpdatedMapping.Status = integ.BlockMappingStatusMapped
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
// 		u.Title.Mapping.Status = integration.BlockMappingStatusError
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

func (u *Updater) GenerateConfig() *integ.BlockMappingConfig {
	config := &integ.BlockMappingConfig{}

	// Add file mapping
	if u.File.UpdatedMapping != nil {
		config.File = []integ.NotionMapping{
			*u.File.UpdatedMapping,
		}
	} else if u.File.CurrentMapping != nil {
		config.File = []integ.NotionMapping{
			*u.File.CurrentMapping,
		}
	}

	// Add audio mappings
	if len(u.AudioTranscription.UpdatedMappings) > 0 {
		config.Audio = []integ.AudioMapping{
			{
				Transcription: u.AudioTranscription.UpdatedMappings,
			},
		}
	} else if len(u.AudioTranscription.CurrentMappings) > 0 {
		config.Audio = []integ.AudioMapping{
			{
				Transcription: u.AudioTranscription.CurrentMappings,
			},
		}
	}

	// Add title mapping
	if u.Title.UpdatedMapping != nil {
		config.Title = []integ.NotionMapping{
			*u.Title.UpdatedMapping,
		}
	} else if u.Title.CurrentMapping != nil {
		config.Title = []integ.NotionMapping{
			*u.Title.CurrentMapping,
		}
	}

	return config
}

func (u *Updater) GenerateConfigDiff() *integ.BlockMappingConfig {
	config := &integ.BlockMappingConfig{}
	// Add updated file mapping
	if u.File.UpdatedMapping != nil {
		config.File = []integ.NotionMapping{
			*u.File.UpdatedMapping,
		}
	}
	// Add updated audio mappings
	if len(u.AudioTranscription.UpdatedMappings) > 0 {
		config.Audio = []integ.AudioMapping{
			{
				Transcription: u.AudioTranscription.UpdatedMappings,
			},
		}
	}
	// Add updated title mapping
	if u.Title.UpdatedMapping != nil {
		config.Title = []integ.NotionMapping{
			*u.Title.UpdatedMapping,
		}
	}
	return config
}
