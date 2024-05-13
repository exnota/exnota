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
	) (*lib_integ.GetSuggestedDestinationsResponse, error)
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
) (*lib_integ.GetSuggestedDestinationsResponse, error) {
	integration, err := s.integrationFetcher.FetchById(integ.FetchByIdRequest{
		IntegrationId: request.IntegrationID,
		UserId:        request.UserID,
	})
	if err != nil {
		return nil, err
	}

	switch integration.Type() {
	case integ.IntegrationTypeNotion:
		result, err := notion.NewGetSuggestedNotionDestinations(s.app, s.integrationFetcher).
			Get(request)
		if err != nil {
			return nil, err
		}
		return result, nil
	default:
		return nil, fmt.Errorf("unsupported integration type: %s", integration.Type())
	}
}
