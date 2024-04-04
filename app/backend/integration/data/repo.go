package data

import (
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationFetcher interface {
	FetchById(id string) (Integration, error)
	FetchNotionIntegration(id string) (NotionIntegration, error)
}

type integrationFetcher struct {
	app core.App
}

func NewIntegrationFetcher(app core.App) IntegrationFetcher {
	return &integrationFetcher{app}
}

func (f *integrationFetcher) FetchById(id string) (Integration, error) {
	record, err := f.app.Dao().FindRecordById(CollectionIntegration, id)
	if err != nil {
		return nil, err
	}
	integration, err := NewIntegration(record)
	if err != nil {
		return nil, err
	}
	return integration, nil
}

func (f *integrationFetcher) FetchNotionIntegration(id string) (NotionIntegration, error) {
	record, err := f.app.Dao().FindRecordById(CollectionIntegration, id)
	if err != nil {
		return nil, err
	}
	integration, err := NewNotionIntegration(record)
	if err != nil {
		return nil, err
	}
	return integration, nil
}
