package data

import (
	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/core"
)

type destinationFetcher struct {
	app core.App
}

func NewDestinationFetcher(app core.App) block.DestinationFetcher {
	return &destinationFetcher{app}
}

func (f *destinationFetcher) FetchById(id string) (block.Destination, error) {
	record, err := f.app.Dao().FindRecordById(block.CollectionDestination, id)
	if err != nil {
		return nil, err
	}
	destination, err := block.NewDestination(record, f.app)
	if err != nil {
		return nil, err
	}
	return destination, nil
}
