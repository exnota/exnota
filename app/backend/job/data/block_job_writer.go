package data

import (
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/models"
)

type BlockJobWriter interface {
	CreateTranscriptionJob(blockId string, userId string) error
	CreateExportJob(blockId string, userId string) error
	SetStatusWaiting(id string) error
	SetStatusRunning(id string) error
	SetStatusError(id string, nextRunAt time.Time, err error) error
	SetStatusComplete(id string) error
}

type blockJobWriter struct {
	app core.App
}

func NewBlockJobWriter(app core.App) BlockJobWriter {
	return &blockJobWriter{app}
}

func (b *blockJobWriter) CreateTranscriptionJob(blockId string, userId string) error {
	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		collection, err := b.app.Dao().FindCollectionByNameOrId(CollectionBlockJob)
		if err != nil {
			return err
		}

		blockJobRecord := models.NewRecord(collection)
		blockJob, err := NewBlockJob(blockJobRecord, b.app)
		if err != nil {
			return err
		}
		blockJob.SetType(BlockJobTypeTranscription)
		blockJob.SetStatus(BlockJobStatusWaiting)
		blockJob.SetBlock(blockId)
		blockJob.SetUser(userId)
		blockJob.SetNextRunAt(time.Now())

		return blockJob.ValidateAndSubmit(txDao)
	})
}

func (b *blockJobWriter) CreateExportJob(blockId string, userId string) error {
	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		collection, err := b.app.Dao().FindCollectionByNameOrId(CollectionBlockJob)
		if err != nil {
			return err
		}

		blockJobRecord := models.NewRecord(collection)
		blockJob, err := NewBlockJob(blockJobRecord, b.app)
		if err != nil {
			return err
		}
		blockJob.SetType(BlockJobTypeExport)
		blockJob.SetStatus(BlockJobStatusWaiting)
		blockJob.SetBlock(blockId)
		blockJob.SetUser(userId)
		blockJob.SetNextRunAt(time.Now())

		return blockJob.ValidateAndSubmit(txDao)
	})
}

func (b *blockJobWriter) SetStatusWaiting(id string) error {
	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(CollectionBlockJob, id)
		if err != nil {
			return err
		}
		blockJob, err := NewBlockJob(record, b.app)
		if err != nil {
			return err
		}

		blockJob.SetStatus(BlockJobStatusWaiting)
		blockJob.SetSummaryEmpty()
		return blockJob.ValidateAndSubmit(txDao)
	})
}

func (b *blockJobWriter) SetStatusRunning(id string) error {
	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(CollectionBlockJob, id)
		if err != nil {
			return err
		}
		blockJob, err := NewBlockJob(record, b.app)
		if err != nil {
			return err
		}
		blockJob.SetStatus(BlockJobStatusRunning)
		blockJob.SetSummaryEmpty()
		return blockJob.ValidateAndSubmit(txDao)
	})
}

func (b *blockJobWriter) SetStatusError(id string, nextRunAt time.Time, statusError error) error {
	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(CollectionBlockJob, id)
		if err != nil {
			return err
		}
		blockJob, err := NewBlockJob(record, b.app)
		if err != nil {
			return err
		}
		blockJob.SetStatus(BlockJobStatusError)
		blockJob.SetSummaryError(statusError)
		blockJob.IncrementErrorCount()
		blockJob.SetNextRunAt(nextRunAt)
		return blockJob.ValidateAndSubmit(txDao)
	})
}

func (b *blockJobWriter) SetStatusComplete(id string) error {
	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(CollectionBlockJob, id)
		if err != nil {
			return err
		}
		blockJob, err := NewBlockJob(record, b.app)
		if err != nil {
			return err
		}
		blockJob.SetStatus(BlockJobStatusComplete)
		blockJob.SetSummaryEmpty()
		return blockJob.ValidateAndSubmit(txDao)
	})
}
