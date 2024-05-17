package data

import (
	"exnota.com/backend/block"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type destinationFetcher struct {
	app core.App
}

func NewDestinationFetcher(app core.App) block.DestinationFetcher {
	return &destinationFetcher{app}
}

func (f *destinationFetcher) FetchById(id string) (block.Destination, error) {
	record, err := f.app.Dao().FindRecordById(block.CollectionDestination, id)
	if err != nil {
		return nil, err
	}
	destination, err := block.LoadDestination(record, f.app)
	if err != nil {
		return nil, err
	}
	return destination, nil
}

func (f *destinationFetcher) ListIdsByIntegrationId(
	workspaceIntegrationId string,
) ([]string, error) {
	// Workspaces for integration
	workspaceFilter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  block.WorkspaceFieldIntegration,
			Op:    filter.OpEquals,
			Value: workspaceIntegrationId,
		},
		filter.Field{
			Name:        block.WorkspaceFieldArchived,
			Op:          filter.OpEquals,
			ValuePreset: filter.ValuePresetNull,
		},
	)
	if err != nil {
		return nil, err
	}
	workspaces, err := f.app.Dao().
		FindRecordsByFilter(
			block.CollectionWorkspace,
			workspaceFilter.Filter,
			"", 0, 0,
			workspaceFilter.Params,
		)
	if err != nil {
		return nil, err
	}

	// Destinations for workspaces
	//
	// Generate separate ID filters for each workspace and combine them with OR,
	// as there's currently no 'IN' operator: https://github.com/pocketbase/pocketbase/issues/4596
	destinationIdFilters := make([]*filter.Filter, len(workspaces))
	for i, workspace := range workspaces {
		destinationFilter, err := filter.CreateAndFilter(
			filter.Field{
				Name:  block.DestinationFieldWorkspace,
				Op:    filter.OpEquals,
				Value: workspace.Id,
			},
			filter.Field{
				Name:        block.DestinationFieldArchived,
				Op:          filter.OpEquals,
				ValuePreset: filter.ValuePresetNull,
			},
		)
		if err != nil {
			return nil, err
		}
		destinationIdFilters[i] = destinationFilter
	}
	destinationFilter, err := filter.GroupFiltersWithOr(destinationIdFilters...)
	if err != nil {
		return nil, err
	}
	destinations, err := f.app.Dao().
		FindRecordsByFilter(
			block.CollectionDestination,
			destinationFilter.Filter,
			"", 0, 0,
			destinationFilter.Params,
		)
	if err != nil {
		return nil, err
	}

	// Extract destination ids
	destinationIds := make([]string, len(destinations))
	for i, destination := range destinations {
		destinationIds[i] = destination.Id
	}
	return destinationIds, nil
}
