package data

import (
	"exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/core"
)

type Fetcher interface {
	FetchById(id string) (interface{}, error)
}

type AppFetcher struct {
	app core.App
}

func NewFetcher(app core.App) *AppFetcher {
	return &AppFetcher{app}
}

func (f *AppFetcher) FetchById(id string) (Integration, error) {
	record, err := f.app.Dao().FindRecordById(integration.CollectionIntegration, id)
	if err != nil {
		return nil, err
	}
	integration, err := NewIntegration(record)
	if err != nil {
		return nil, err
	}
	return integration, nil
}
