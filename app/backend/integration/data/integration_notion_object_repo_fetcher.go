package data

import (
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationNotionObjectFetcher interface {
	FetchById(id string) (IntegrationNotionObject, error)
	ListByIds(ids []string) ([]IntegrationNotionObject, error)
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
	return LoadIntegrationNotionObject(record, f.app), nil
}

func (f *integrationNotionObjectFetcher) ListByIds(
	ids []string,
) ([]IntegrationNotionObject, error) {
	records, err := f.app.Dao().FindRecordsByIds(CollectionIntegrationNotionObject, ids)
	if err != nil {
		return nil, err
	}
	objects := make([]IntegrationNotionObject, len(records))
	for i, record := range records {
		objects[i] = LoadIntegrationNotionObject(record, f.app)
	}
	return objects, nil
}
