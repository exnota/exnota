package notion

import (
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/usecase/notion/api"
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type SearchNotionDestinations interface {
	Search(
		request SearchNotionDestinationsRequest,
	) ([]lib_integ.NotionDestination, error)
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

func (s *searchNotionDestinations) Search(
	request SearchNotionDestinationsRequest,
) ([]lib_integ.NotionDestination, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	integration, err := s.integrationFetcher.FetchNotionIntegration(request.IntegrationID)
	if err != nil {
		return nil, err
	}
	config, err := integration.Config()
	if err != nil {
		return nil, err

	}

	// Search any object type
	fetcher := api.NewNotionFetcher(*config.Auth.AccessToken)
	if request.Notion == nil {
		results, err := fetcher.Search(request.Query)
		if err != nil {
			return nil, fmt.Errorf("error searching notion: %w", err)
		}
		mapped, err := mapSearchResultsToDestinations(results)
		if err != nil {
			return nil, fmt.Errorf("error mapping notion results to destinations: %w", err)
		}
		return mapped, nil
	}

	// Search specific object type
	switch *request.Notion.Object {
	case string(NotionObjectTypePage):
		pages, err := fetcher.SearchPages(request.Query)
		if err != nil {
			return nil, fmt.Errorf("error searching pages: %w", err)
		}
		mapped, err := mapPagesToDestinations(pages)
		if err != nil {
			return nil, fmt.Errorf("error mapping pages to destinations: %w", err)
		}
		return mapped, nil
	case string(NotionObjectTypeDatabase):
		databases, err := fetcher.SearchDatabases(request.Query)
		if err != nil {
			return nil, fmt.Errorf("error searching databases: %w", err)
		}
		mapped := mapDatabasesToDestinations(databases)
		return mapped, nil

	default:
		panic(fmt.Sprintf("unsupported notion object type: %s", *request.Notion.Object))
	}
}
