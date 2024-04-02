package data

import (
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationDestinationFetcher interface {
	FetchById(id string) (IntegrationDestination, error)
}

type integrationDestinationFetcher struct {
	app core.App
}

func NewIntegrationDestinationFetcher(app core.App) IntegrationDestinationFetcher {
	return &integrationDestinationFetcher{app: app}
}

func (f *integrationDestinationFetcher) FetchById(id string) (IntegrationDestination, error) {
	record, err := f.app.Dao().FindRecordById(CollectionIntegrationDestination, id)
	if err != nil {
		return nil, err
	}
	return NewIntegrationDestination(record), nil
}
