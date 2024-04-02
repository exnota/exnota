package data

import (
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationNotionObjectFetcher interface {
	FetchById(id string) (IntegrationNotionObject, error)
}

type integrationNotionObjectFetcher struct {
	app core.App
}

func NewIntegrationNotionObjectFetcher(app core.App) IntegrationNotionObjectFetcher {
	return &integrationNotionObjectFetcher{app: app}
}

func (f *integrationNotionObjectFetcher) FetchById(id string) (IntegrationNotionObject, error) {
	record, err := f.app.Dao().FindRecordById(CollectionIntegrationNotionObject, id)
	if err != nil {
		return nil, err
	}
	return NewIntegrationNotionObject(record), nil
}
