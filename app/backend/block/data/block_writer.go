package data

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type BlockWriter interface {
	SetExternalUrl(id string, url string) error
}

type blockWriter struct {
	app core.App
}

func NewBlockWriter(app core.App) BlockWriter {
	return &blockWriter{app}
}

func (f *blockWriter) SetExternalUrl(id string, url string) error {
	return f.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		record, err := f.app.Dao().FindRecordById(CollectionBlock, id)
		if err != nil {
			return err
		}
		block, err := LoadBlock(record, f.app)
		if err != nil {
			return err
		}

		err = block.SetExternalUrl(url)
		if err != nil {
			return err
		}
		return block.ValidateAndSubmit(txDao)
	})
}
