package data

import (
	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/core"
)

type integrationNotionObjectFetcher struct {
	app core.App
}

func NewIntegrationNotionObjectFetcher(app core.App) integ.IntegrationNotionObjectFetcher {
	return &integrationNotionObjectFetcher{app: app}
}

func (f *integrationNotionObjectFetcher) FetchById(
	id string,
) (integ.IntegrationNotionObject, error) {
	record, err := f.app.Dao().FindRecordById(integ.CollectionIntegrationNotionObject, id)
	if err != nil {
		return nil, err
	}
	return integ.LoadIntegrationNotionObject(record, f.app), nil
}

func (f *integrationNotionObjectFetcher) ListByIds(
	ids []string,
) ([]integ.IntegrationNotionObject, error) {
	records, err := f.app.Dao().FindRecordsByIds(integ.CollectionIntegrationNotionObject, ids)
	if err != nil {
		return nil, err
	}
	objects := make([]integ.IntegrationNotionObject, len(records))
	for i, record := range records {
		objects[i] = integ.LoadIntegrationNotionObject(record, f.app)
	}
	return objects, nil
}
