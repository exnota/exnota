package data

import (
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/lib/data/filter"
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

func (f *integrationNotionObjectFetcher) FetchByExternalID(
	request integ.NotionObjectFetchRequest,
) (integ.IntegrationNotionObject, error) {
	filter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  integ.IntegrationNotionObjectFieldExternalId,
			Op:    filter.OpEquals,
			Value: request.ExternalID,
		},
		filter.Field{
			Name:  integ.IntegrationNotionObjectFieldType,
			Op:    filter.OpEquals,
			Value: string(request.Type),
		},
		filter.Field{
			Name:  integ.IntegrationNotionObjectFieldUser,
			Op:    filter.OpEquals,
			Value: request.User,
		},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create filter: %w", err)
	}

	record, err := f.app.Dao().FindFirstRecordByFilter(
		integ.CollectionIntegrationNotionObject,
		filter.Filter,
		filter.Params,
	)
	if err != nil {
		// Returns sql.ErrNoRows here if no record
		return nil, fmt.Errorf("failed to find record: %w", err)
	}
	return integ.LoadIntegrationNotionObject(record, f.app), nil
}
