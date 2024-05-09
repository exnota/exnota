package data

import (
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationDestinationFetcher interface {
	FetchById(id string) (IntegrationDestination, error)
	FetchByDestinationId(destinationId string) (IntegrationDestination, error)
	ListByDestinationIds(destinationIds []string) ([]IntegrationDestination, error)
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

func (f *integrationDestinationFetcher) FetchByDestinationId(
	destinationId string,
) (IntegrationDestination, error) {
	record, err := f.app.Dao().
		FindFirstRecordByData(CollectionIntegrationDestination, IntegrationDestinationFieldDestinationId, destinationId)
	if err != nil {
		return nil, err
	}
	return NewIntegrationDestination(record), nil
}

func (f *integrationDestinationFetcher) ListByDestinationIds(
	destinationIds []string,
) ([]IntegrationDestination, error) {
	// Generate separate ID filters for each destination and combine them with OR,
	// as there's currently no 'IN' operator: https://github.com/pocketbase/pocketbase/issues/4596
	destinationIdFilters := make([]*filter.Filter, len(destinationIds))
	for i, destinationId := range destinationIds {
		filter, err := filter.CreateAndFilter(filter.Field{
			Name:  IntegrationDestinationFieldDestinationId,
			Op:    filter.OpEquals,
			Value: destinationId,
		})
		if err != nil {
			return nil, err
		}
		destinationIdFilters[i] = filter
	}
	filter, err := filter.GroupFiltersWithOr(destinationIdFilters...)
	if err != nil {
		return nil, err
	}
	records, err := f.app.Dao().
		FindRecordsByFilter(CollectionIntegrationDestination,
			filter.Filter, "", 0, 0, filter.Params,
		)
	if err != nil {
		return nil, err
	}

	integrationDestinations := make([]IntegrationDestination, len(records))
	for i, record := range records {
		integrationDestinations[i] = NewIntegrationDestination(record)
	}
	return integrationDestinations, nil
}
