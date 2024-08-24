package usecase

import (
	"fmt"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/usecase/notion"
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
)

type GetSuggestedIntegrationDestinations interface {
	Get(
		request lib_integ.GetSuggestedDestinationsRequest,
	) (*lib_integ.Destinations, error)
}

type getSuggestedIntegrationDestinations struct {
	app                core.App
	integrationFetcher integ.IntegrationFetcher
}

func NewGetSuggestedIntegrationDestinations(
	app core.App,
	integrationFetcher integ.IntegrationFetcher,
) GetSuggestedIntegrationDestinations {
	return &getSuggestedIntegrationDestinations{
		app,
		integrationFetcher,
	}
}

func (s *getSuggestedIntegrationDestinations) Get(
	request lib_integ.GetSuggestedDestinationsRequest,
) (*lib_integ.Destinations, error) {
	integration, err := s.integrationFetcher.FetchById(integ.FetchByIdRequest{
		IntegrationId: request.IntegrationID,
		UserId:        request.UserID,
	})
	if err != nil {
		return nil, err
	}
	if !integration.Archived().IsZero() {
		return nil, fmt.Errorf("integration is archived")
	}

	switch integration.Type() {
	case integ.IntegrationTypeNotion:
		results, err := notion.NewGetSuggestedNotionDestinations(s.app, s.integrationFetcher).
			Get(request)
		if err != nil {
			return nil, err
		}
		return &lib_integ.Destinations{
			Notion: results,
		}, nil
	default:
		return nil, fmt.Errorf("unsupported integration type: %s", integration.Type())
	}
}
