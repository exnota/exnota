package data

import (
	"github.com/pocketbase/pocketbase/core"
)

type DestinationFetcher interface {
	FetchById(id string) (Destination, error)
}

type destinationFetcher struct {
	app core.App
}

func NewDestinationFetcher(app core.App) DestinationFetcher {
	return &destinationFetcher{app}
}

func (f *destinationFetcher) FetchById(id string) (Destination, error) {
	record, err := f.app.Dao().FindRecordById(CollectionDestination, id)
	if err != nil {
		return nil, err
	}
	destination, err := NewDestination(record)
	if err != nil {
		return nil, err
	}
	return destination, nil
}
