package job

import (
	block_data "exnota.com/backend/block/data"
	"exnota.com/backend/job/data"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type BlockJobWorkflow interface {
	ApplyHooks()
}

type blockJobWorkflow struct {
	app core.App
}

func NewBlockJobWorkflow(app core.App) BlockJobWorkflow {
	return &blockJobWorkflow{
		app: app,
	}
}

func (j *blockJobWorkflow) ApplyHooks() {
	j.createNewVoiceNoteJobs()
	// j.createAddTranscriptionJob()
}

func (j *blockJobWorkflow) createNewVoiceNoteJobs() {
	j.app.OnModelAfterCreate(block_data.CollectionBlock).Add(func(e *core.ModelEvent) error {
		blockRecord := e.Model.(*models.Record)
		block, err := block_data.NewBlock(blockRecord)
		if err != nil {
			return err
		}

		if block.Type() == block_data.BlockTypeVoiceNote {
			blockJobWriter := data.NewBlockJobWriter(j.app)

			// Create transcription job
			err := blockJobWriter.CreateTranscriptionJob(
				block.Id(),
				block.User(),
			)
			if err != nil {
				return err
			}

			// Create export job
			file := block.File()
			var audio *data.AudioField
			if audioBlock, ok := block.(block_data.VoiceNoteBlock); ok {
				blockAudio, err := audioBlock.Audio()
				if err != nil {
					return err
				}
				if blockAudio != nil {
					audio = &data.AudioField{
						Transcription: blockAudio.Transcription,
					}
				}
			}
			err = blockJobWriter.CreateExportJob(data.CreateCreateVoiceNoteRequest{
				BlockId: block.Id(),
				UserId:  block.User(),
				Config: data.ExportJobConfig{
					Command: data.CommandCreateVoiceNote,
					Data: data.ExportJobData{
						Id:          block.Id(),
						Type:        data.BlockTypeVoiceNote,
						Destination: block.Destination(),
						File:        &file,
						Title:       block.Title(),
						Audio:       audio,
					},
				},
			})
			if err != nil {
				return err
			}
		}
		return nil
	})
}

// func (j *blockJobWorkflow) createAddTranscriptionJob() {
// 	// On transcription job completion, create an export job
// 	j.app.OnModelAfterUpdate(data.CollectionBlockJob).Add(func(e *core.ModelEvent) error {
// 		// Transcription jobs only
// 		updatedJob, err := data.NewBlockJob(e.Model.(*models.Record), j.app)
// 		if err != nil {
// 			return err
// 		}
// 		if updatedJob.Type() != data.BlockJobTypeTranscription {
// 			return nil
// 		}

// 		// Job complete events only
// 		if updatedJob.Status() != data.BlockJobStatusComplete {
// 			return nil
// 		}
// 		prevUpdatedJob, err := data.NewBlockJob(updatedJob.Record().OriginalCopy(), j.app)
// 		if err != nil {
// 			return err
// 		}
// 		if prevUpdatedJob.Status() == data.BlockJobStatusComplete {
// 			return nil
// 		}

// 		// Create export job
// 		blockJobFetcher := block_data.NewBlockFetcher(j.app)
// 		block, err := blockJobFetcher.FetchById(updatedJob.Block())
// 		if err != nil {
// 			return err
// 		}

// 		// get transcription
// 		var audio *data.AudioField
// 		if audioBlock, ok := block.(block_data.VoiceNoteBlock); ok {
// 			blockAudio, err := audioBlock.Audio()
// 			if err != nil {
// 				return err
// 			}
// 			audio = &data.AudioField{
// 				Transcription: blockAudio.Transcription,
// 			}
// 		}
// 		// TODO: Where to update title?
// 		err = blockJobWriter.CreateExportJob(data.CreateCreateVoiceNoteRequest{
// 			BlockId: block.Id(),
// 			UserId:  block.User(),
// 			Config: data.ExportJobConfig{
// 				Command: data.CommandCreateVoiceNote,
// 				Data: data.ExportJobData{
// 					Id:          block.Id(),
// 					Type:        data.BlockTypeVoiceNote,
// 					Destination: block.Destination(),
// 					// TODO: Test that audio is updated
// 					Audio: audio,
// 				},
// 			},
// 		})
// 		if err != nil {
// 			return err
// 		}

// 		return err
// 	})
// }
