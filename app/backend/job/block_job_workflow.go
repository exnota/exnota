package job

import (
	"exnota.com/backend/block"
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
	j.createAddTranscriptionJob()
}

func (j *blockJobWorkflow) createNewVoiceNoteJobs() {
	j.app.OnModelAfterCreate(block.CollectionBlock).Add(func(e *core.ModelEvent) error {
		blockRecord := e.Model.(*models.Record)
		b, err := block.LoadBlock(blockRecord, j.app)
		if err != nil {
			return err
		}

		if b.Type() == block.BlockTypeVoiceNote {
			blockJobWriter := data.NewBlockJobWriter(j.app)

			// Create transcription job
			err := blockJobWriter.CreateTranscriptionJob(
				b.Id(),
				b.User(),
			)
			if err != nil {
				return err
			}

			// Create export job
			file := b.File()
			var audio *data.AudioField
			if audioBlock, ok := b.(block.VoiceNoteBlock); ok {
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
				BlockId: b.Id(),
				UserId:  b.User(),
				Config: data.ExportJobConfig{
					Command: data.CommandCreateVoiceNote,
					Data: data.ExportJobData{
						Id:          b.Id(),
						Type:        data.BlockTypeVoiceNote,
						Destination: b.Destination(),
						File:        &file,
						Title:       b.Title(),
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

func (j *blockJobWorkflow) createAddTranscriptionJob() {
	// Create add transcription export job when both transcription job and
	// create voice note export job are completed.
	j.app.OnModelAfterUpdate(data.CollectionBlockJob).Add(func(e *core.ModelEvent) error {
		updatedJob, err := data.LoadBlockJob(e.Model.(*models.Record), j.app)
		if err != nil {
			return err
		}

		switch updatedJob.Type() {
		case data.BlockJobTypeTranscription:
			// Option 1: This is a transcription job completion event, and an export
			// job for creating a voice note has already been completed.

			// Ignore non-job completion events
			if updatedJob.Status() != data.BlockJobStatusComplete {
				return nil
			}
			prevUpdatedJob, err := data.LoadBlockJob(updatedJob.Record().OriginalCopy(), j.app)
			if err != nil {
				return err
			}
			if prevUpdatedJob.Status() == data.BlockJobStatusComplete {
				return nil
			}

			// Ensure export job with command CommandCreateVoiceNote has been
			// completed
			blockJobFetcher := data.NewBlockJobFetcher(j.app)
			jobs, err := blockJobFetcher.ListExportJobs(data.ListExportJobsRequest{
				BlockId: updatedJob.Block(),
				UserId:  updatedJob.User(),
				Command: data.CommandCreateVoiceNote,
				Status:  data.BlockJobStatusComplete,
			})
			if err != nil {
				return err
			}
			if len(jobs) == 0 {
				return nil
			}
		case data.BlockJobTypeExport:
			// Option 2: This is an export job completion event for creating a
			// voice note, and transcription job is already complete.

			// Ignore other export job command types
			exportJob, err := data.LoadExportBlockJob(updatedJob.Record(), j.app)
			if err != nil {
				return err
			}
			config, err := exportJob.Config()
			if err != nil {
				return err
			}
			if config.Command != data.CommandCreateVoiceNote {
				return nil
			}

			// Ignore non-job completion events
			if exportJob.Status() != data.BlockJobStatusComplete {
				return nil
			}
			prevExportJob, err := data.LoadBlockJob(exportJob.Record().OriginalCopy(), j.app)
			if err != nil {
				return err
			}
			if prevExportJob.Status() == data.BlockJobStatusComplete {
				return nil
			}

			// Ensure transcription job has been completed
			blockJobFetcher := data.NewBlockJobFetcher(j.app)
			jobTranscription := data.BlockJobTypeTranscription
			jobComplete := data.BlockJobStatusComplete
			jobs, err := blockJobFetcher.ListJobs(data.ListJobsRequest{
				BlockId: updatedJob.Block(),
				UserId:  updatedJob.User(),
				Type:    &jobTranscription,
				Status:  &jobComplete,
			})
			if err != nil {
				return err
			}
			if len(jobs) == 0 {
				return nil
			}
		default:
			return nil
		}

		// Create export job
		blockJobFetcher := block_data.NewBlockFetcher(j.app)
		b, err := blockJobFetcher.FetchById(updatedJob.Block())
		if err != nil {
			return err
		}

		// get transcription
		var audio *data.AudioField
		if audioBlock, ok := b.(block.VoiceNoteBlock); ok {
			blockAudio, err := audioBlock.Audio()
			if err != nil {
				return err
			}
			audio = &data.AudioField{
				Transcription: blockAudio.Transcription,
			}
		}
		blockJobWriter := data.NewBlockJobWriter(j.app)
		err = blockJobWriter.CreateExportJob(data.CreateCreateVoiceNoteRequest{
			BlockId: b.Id(),
			UserId:  b.User(),
			Config: data.ExportJobConfig{
				Command: data.CommandAddTranscription,
				Data: data.ExportJobData{
					// Mandatory fields
					Id:          b.Id(),
					Type:        data.BlockTypeVoiceNote,
					Destination: b.Destination(),

					// Updated fields
					Title: b.Title(),
					Audio: audio,
				},
			},
		})

		return err
	})
}
