package data

import (
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type BlockJobWriter interface {
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

func (b *blockJobWriter) SetStatusWaiting(id string) error {
	return b.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := txDao.FindRecordById(CollectionBlockJob, id)
		if err != nil {
			return err
		}
		blockJob := NewBlockJob(record, b.app)
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
		blockJob := NewBlockJob(record, b.app)
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
		blockJob := NewBlockJob(record, b.app)
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
		blockJob := NewBlockJob(record, b.app)
		blockJob.SetStatus(BlockJobStatusComplete)
		blockJob.SetSummaryEmpty()
		return blockJob.ValidateAndSubmit(txDao)
	})
}
