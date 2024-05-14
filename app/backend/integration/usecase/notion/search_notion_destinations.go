package notion

import (
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/usecase/notion/api"
	lib "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type SearchNotionDestinations interface {
	SearchDatabaseDestinations(
		integrationID string,
		query string,
	) ([]lib.NotionDestination, error)
	SearchAllDestinations(
		integrationID string,
		query string,
	) ([]lib.NotionDestination, error)
}

type searchNotionDestinations struct {
	app                core.App
	integrationFetcher integ.IntegrationFetcher
}

func NewSearchNotionDestinations(
	app core.App,
	integrationFetcher integ.IntegrationFetcher,
) SearchNotionDestinations {
	return &searchNotionDestinations{
		app,
		integrationFetcher,
	}
}

type SearchNotionDestinationsRequest struct {
	IntegrationID string `validate:"min=1"`
	Query         string
	Notion        *NotionSearchParams
}

type NotionSearchParams struct {
	Object *string `validate:"omitempty,oneof=page database"`
}

type NotionObjectType string

const (
	NotionObjectTypePage     NotionObjectType = "page"
	NotionObjectTypeDatabase NotionObjectType = "database"
)

func (s *searchNotionDestinations) SearchDatabaseDestinations(
	integrationID string,
	query string,
) ([]lib.NotionDestination, error) {
	integration, err := s.integrationFetcher.FetchNotionIntegration(integrationID)
	if err != nil {
		return nil, err
	}
	config, err := integration.Config()
	if err != nil {
		return nil, err

	}

	fetcher := api.NewNotionFetcher(*config.Auth.AccessToken)
	databases, err := fetcher.SearchDatabases(query)
	if err != nil {
		return nil, fmt.Errorf("error searching databases: %w", err)
	}
	mapped := mapDatabasesToDestinations(databases)
	return mapped, nil
}

func (s *searchNotionDestinations) SearchAllDestinations(
	integrationID string,
	query string,
) ([]lib.NotionDestination, error) {
	integration, err := s.integrationFetcher.FetchNotionIntegration(integrationID)
	if err != nil {
		return nil, err
	}
	config, err := integration.Config()
	if err != nil {
		return nil, err

	}

	fetcher := api.NewNotionFetcher(*config.Auth.AccessToken)
	databases, err := fetcher.Search(query)
	if err != nil {
		return nil, fmt.Errorf("error searching databases: %w", err)
	}
	mapped, err := mapSearchResultsToDestinations(databases)
	if err != nil {
		return nil, fmt.Errorf("error mapping search results to destinations: %w", err)
	}
	return mapped, nil

}
