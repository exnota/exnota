package data

import (
	"fmt"
	"log/slog"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type integrationFetcher struct {
	app core.App
}

func NewIntegrationFetcher(app core.App) integ.IntegrationFetcher {
	return &integrationFetcher{app}
}

func (f *integrationFetcher) FetchById(
	request integ.FetchByIdRequest,
) (integ.Integration, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	record, err := f.app.Dao().
		FindRecordById(integ.CollectionIntegration, request.IntegrationId)
	if err != nil {
		return nil, err
	}
	integration, err := integ.LoadIntegration(record, f.app)
	if err != nil {
		return nil, err
	}

	if integration.User() != request.UserId {
		slog.Error(
			"Integration user id does not match",
			"integration",
			integration,
			"userId",
			request.UserId,
		)
		return nil, fmt.Errorf("Integration user id does not match")
	}

	return integration, nil
}

func (f *integrationFetcher) FetchNotionIntegration(
	id string,
) (integ.NotionIntegration, error) {
	record, err := f.app.Dao().FindRecordById(integ.CollectionIntegration, id)
	if err != nil {
		return nil, err
	}

	integration, err := integ.LoadNotionIntegration(record, f.app)
	if err != nil {
		slog.Error("Error creating notion integration", "err", err)
		return nil, err
	}
	return integration, nil
}

func (f *integrationFetcher) ListByNotionBotId(
	botId string,
) ([]integ.NotionIntegration, error) {
	filter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  integ.IntegrationFieldType,
			Op:    filter.OpEquals,
			Value: integ.IntegrationTypeNotion,
		},
		filter.Field{
			Name:  integ.FilterConfigBotId,
			Op:    filter.OpEquals,
			Value: botId,
		},
		filter.Field{
			Name:        integ.IntegrationFieldArchived,
			Op:          filter.OpEquals,
			ValuePreset: filter.ValuePresetNull,
		},
	)
	if err != nil {
		return nil, err
	}
	records, err := f.app.Dao().
		FindRecordsByFilter(integ.CollectionIntegration, filter.Filter, "", 0, 0, filter.Params)
	if err != nil {
		return nil, err
	}

	var integrations []integ.NotionIntegration
	for _, record := range records {
		integration, err := integ.LoadNotionIntegration(record, f.app)
		if err != nil {
			slog.Error("Error creating notion integration", "err", err)
			return nil, err
		}
		integrations = append(integrations, integration)
	}

	return integrations, nil
}
