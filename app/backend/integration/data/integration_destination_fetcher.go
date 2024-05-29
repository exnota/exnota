package data

import (
	"database/sql"
	"errors"
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type integrationDestinationFetcher struct {
	app                core.App
	destinationFetcher DestinationFetcher
}

type DestinationFetcher interface {
	Exists(id string) error
}

func NewIntegrationDestinationFetcher(
	app core.App,
	destinationFetcher DestinationFetcher,
) integ.IntegrationDestinationFetcher {
	return &integrationDestinationFetcher{app, destinationFetcher}
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

func (f *integrationDestinationFetcher) FetchByDestinationID(
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

	records, err := f.app.Dao().FindRecordsByFilter(
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

	var integrationDestinations []integ.IntegrationDestination
	for _, r := range records {
		// Verify the destination exists.
		//
		// Creating a destination with an integration destination join table
		// entry is not transactional, so it's possible for the join table
		// entry to exist without a corresponding destination.
		integDest := integ.NewIntegrationDestination(r)
		if err := f.destinationFetcher.Exists(integDest.DestinationId()); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				// Skip orphaned integration destination
				continue
			}
			return nil, fmt.Errorf(
				"Error verifying destination %v for integration destination %v: %w",
				integDest.DestinationId(),
				integDest.Id(),
				err,
			)
		}
		integrationDestinations = append(integrationDestinations, integDest)
	}
	return integrationDestinations, nil
}

func (f *integrationDestinationFetcher) ListByDestinationIDs(
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
