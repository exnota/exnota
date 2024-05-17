package data

import (
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type integrationDestinationFetcher struct {
	app core.App
}

func NewIntegrationDestinationFetcher(app core.App) integ.IntegrationDestinationFetcher {
	return &integrationDestinationFetcher{app}
}

func (f *integrationDestinationFetcher) FetchById(
	id string,
) (integ.IntegrationDestination, error) {
	record, err := f.app.Dao().FindRecordById(integ.CollectionIntegrationDestination, id)
	if err != nil {
		return nil, err
	}
	return integ.NewIntegrationDestination(record), nil
}

func (f *integrationDestinationFetcher) FetchByDestinationId(
	destinationId string,
) (integ.IntegrationDestination, error) {
	record, err := f.app.Dao().
		FindFirstRecordByData(integ.CollectionIntegrationDestination, integ.IntegrationDestinationFieldDestinationId, destinationId)
	if err != nil {
		return nil, err
	}
	return integ.NewIntegrationDestination(record), nil
}

// If not found, returns wrapped sql.ErrNoRows
func (f *integrationDestinationFetcher) ListByExternalID(
	externalRecordId string,
) ([]integ.IntegrationDestination, error) {
	filter, err := filter.CreateAndFilter(filter.Field{
		Name:  integ.IntegrationDestinationFieldExternalRecordId,
		Op:    filter.OpEquals,
		Value: externalRecordId,
	})
	if err != nil {
		return nil, err
	}

	record, err := f.app.Dao().FindRecordsByFilter(
		integ.CollectionIntegrationDestination,
		filter.Filter,
		"",
		0,
		0,
		filter.Params,
	)
	if err != nil {
		return nil, fmt.Errorf(
			"Error listing integration destinations for external record ID %v: %w",
			externalRecordId,
			err,
		)
	}

	integrationDestinations := make([]integ.IntegrationDestination, len(record))
	for i, r := range record {
		integrationDestinations[i] = integ.NewIntegrationDestination(r)
	}
	return integrationDestinations, nil
}

func (f *integrationDestinationFetcher) ListByDestinationIds(
	destinationIds []string,
) ([]integ.IntegrationDestination, error) {
	// Generate separate ID filters for each destination and combine them with OR,
	// as there's currently no 'IN' operator: https://github.com/pocketbase/pocketbase/issues/4596
	destinationIdFilters := make([]*filter.Filter, len(destinationIds))
	for i, destinationId := range destinationIds {
		filter, err := filter.CreateAndFilter(filter.Field{
			Name:  integ.IntegrationDestinationFieldDestinationId,
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
		FindRecordsByFilter(integ.CollectionIntegrationDestination,
			filter.Filter, "", 0, 0, filter.Params,
		)
	if err != nil {
		return nil, err
	}

	integrationDestinations := make([]integ.IntegrationDestination, len(records))
	for i, record := range records {
		integrationDestinations[i] = integ.NewIntegrationDestination(record)
	}
	return integrationDestinations, nil
}
