package data

import (
	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type blockFetcher struct {
	app core.App
}

func NewBlockFetcher(app core.App) block.BlockFetcher {
	return &blockFetcher{app}
}

func (f *blockFetcher) FetchById(id string) (block.Block, error) {
	record, err := f.app.Dao().FindRecordById(block.CollectionBlock, id)
	if err != nil {
		return nil, err
	}
	block, err := block.LoadBlock(record, f.app)
	if err != nil {
		return nil, err
	}
	return block, nil
}

func (f *blockFetcher) FetchVoiceNoteByIdInTx(
	txDao *daos.Dao,
	id string,
) (block.VoiceNoteBlock, error) {
	record, err := txDao.FindRecordById(block.CollectionBlock, id)
	if err != nil {
		return nil, err
	}
	block, err := block.LoadVoiceNoteBlock(record, f.app)
	if err != nil {
		return nil, err
	}
	return block, nil
}
