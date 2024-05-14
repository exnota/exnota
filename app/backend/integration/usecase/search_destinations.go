package usecase

import (
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/usecase/notion"
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type SearchDestinations interface {
	Search(
		request SearchDestinationsRequest,
	) (*SearchDestinationsResponse, error)
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
	Notion        *notion.NotionSearchParams
}

type SearchDestinationsResponse struct {
	NotionDestinations []lib_integ.NotionDestination `json:"notion_destinations" validate:"required"`
}

func (s *searchDestinations) Search(
	request SearchDestinationsRequest,
) (*SearchDestinationsResponse, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	integration, err := s.integrationFetcher.FetchById(integ.FetchByIdRequest{
		IntegrationId: request.IntegrationID,
		UserId:        request.UserID,
	})
	if err != nil {
		return nil, err
	}

	switch integration.Type() {
	case integ.IntegrationTypeNotion:
		result, err := notion.NewSearchNotionDestinations(s.app, s.integrationFetcher).
			Search(notion.SearchNotionDestinationsRequest{
				IntegrationID: request.IntegrationID,
				Query:         request.Query,
				Notion:        request.Notion,
			})
		if err != nil {
			return nil, err
		}
		return &SearchDestinationsResponse{
			NotionDestinations: result,
		}, nil
	default:
		return nil, fmt.Errorf("unsupported integration type: %s", integration.Type())
	}
}
