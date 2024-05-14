package usecase

import (
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/usecase/notion"
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type SearchDestinations interface {
	SearchDatabaseDestinations(
		integrationId string,
		userId string,
		query string,
	) (*lib_integ.Destinations, error)
	SearchAllDestinations(
		integrationId string,
		userId string,
		query string,
	) (*lib_integ.Destinations, error)
}

type searchDestinations struct {
	app                core.App
	integrationFetcher integ.IntegrationFetcher
}

func NewSearchDestinations(
	app core.App,
	integrationFetcher integ.IntegrationFetcher,
) SearchDestinations {
	return &searchDestinations{
		app,
		integrationFetcher,
	}
}

type SearchDestinationsRequest struct {
	IntegrationID string `validate:"min=1"`
	UserID        string `validate:"min=1"`
	Query         string
	WorkspaceType string `validate:"oneof=database custom" json:"workspace_type"`
}

type SearchDestinationsResponse struct {
	NotionDestinations []lib_integ.NotionDestination `json:"notion_destinations" validate:"required"`
}

func (s *searchDestinations) SearchDatabaseDestinations(
	integrationID string,
	userID string,
	query string,
) (*lib_integ.Destinations, error) {
	integration, err := s.integrationFetcher.FetchById(integ.FetchByIdRequest{
		IntegrationId: integrationID,
		UserId:        userID,
	})
	if err != nil {
		return nil, err
	}

	switch integration.Type() {
	case integ.IntegrationTypeNotion:
		result, err := notion.NewSearchNotionDestinations(s.app, s.integrationFetcher).
			SearchDatabaseDestinations(integrationID, query)
		if err != nil {
			return nil, err
		}
		return &lib_integ.Destinations{
			Notion: result,
		}, nil
	default:
		panic(fmt.Sprintf("unsupported integration type: %s", integration.Type()))
	}
}

func (s *searchDestinations) SearchAllDestinations(
	integrationID string,
	userID string,
	query string,
) (*lib_integ.Destinations, error) {
	integration, err := s.integrationFetcher.FetchById(integ.FetchByIdRequest{
		IntegrationId: integrationID,
		UserId:        userID,
	})
	if err != nil {
		return nil, err
	}

	switch integration.Type() {
	case integ.IntegrationTypeNotion:
		result, err := notion.NewSearchNotionDestinations(s.app, s.integrationFetcher).
			SearchAllDestinations(integrationID, query)
		if err != nil {
			return nil, err
		}
		return &lib_integ.Destinations{
			Notion: result,
		}, nil
	default:
		panic(fmt.Sprintf("unsupported integration type: %s", integration.Type()))
	}
}
