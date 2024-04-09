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
	j.createTranscriptionJob()
	j.createExportJob()
}

func (j *blockJobWorkflow) createTranscriptionJob() {
	// On voice note creation, create a transcription job
	j.app.OnModelAfterCreate(block_data.CollectionBlock).Add(func(e *core.ModelEvent) error {
		blockRecord := e.Model.(*models.Record)
		block, err := block_data.NewBlock(blockRecord)
		if err != nil {
			return err
		}

		if block.Type() == block_data.BlockTypeVoiceNote {
			blockJobWriter := data.NewBlockJobWriter(j.app)
			err := blockJobWriter.CreateTranscriptionJob(
				block.Id(),
				block.User(),
			)
			if err != nil {
				return err
			}
		}
		return nil
	})
}

func (j *blockJobWorkflow) createExportJob() {
	// On transcription job completion, create an export job
	j.app.OnModelAfterUpdate(data.CollectionBlockJob).Add(func(e *core.ModelEvent) error {
		// Transcription jobs only
		updatedJob := data.NewBlockJob(e.Model.(*models.Record), j.app)
		if updatedJob.Type() != data.BlockJobTypeTranscription {
			return nil
		}

		// Job complete events only
		if updatedJob.Status() != data.BlockJobStatusComplete {
			return nil
		}
		prevUpdatedJob := data.NewBlockJob(updatedJob.Record().OriginalCopy(), j.app)
		if prevUpdatedJob.Status() == data.BlockJobStatusComplete {
			return nil
		}

		collection, err := j.app.Dao().FindCollectionByNameOrId(data.CollectionBlockJob)
		if err != nil {
			return err
		}

		form, err := data.NewExportBlockJobForm(data.NewExportBlockJobFormConfig{
			Collection: collection,
			App:        j.app,
			BlockId:    updatedJob.Block(),
			UserId:     updatedJob.User(),
		})
		if err != nil {
			return err
		}

		// validate and submit (internally it calls app.Dao().SaveRecord(record) in a transaction)
		if err := form.Submit(); err != nil {
			return err
		}
		return nil
	})
}
