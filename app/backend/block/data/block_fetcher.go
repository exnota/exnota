package data

import (
	"github.com/pocketbase/pocketbase/core"
)

type BlockFetcher interface {
	FetchById(id string) (Block, error)
}

type blockFetcher struct {
	app core.App
}

func NewBlockFetcher(app core.App) BlockFetcher {
	return &blockFetcher{app}
}

func (f *blockFetcher) FetchById(id string) (Block, error) {
	record, err := f.app.Dao().FindRecordById(CollectionBlock, id)
	if err != nil {
		return nil, err
	}
	block, err := LoadBlock(record, f.app)
	if err != nil {
		return nil, err
	}
	return block, nil
}
