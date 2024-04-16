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
	// j.createExportJob()
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

// TODO: Update this to be exporting an 'addTranscription' job
// func (j *blockJobWorkflow) createExportJob() {
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
// 		blockJobWriter := data.NewBlockJobWriter(j.app)
// 		err = blockJobWriter.CreateExportJob(
// 			updatedJob.Block(),
// 			updatedJob.User(),
// 		)

// 		return err
// 	})
// }
