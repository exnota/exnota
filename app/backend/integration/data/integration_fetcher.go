package data

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationFetcher interface {
	FetchById(id string, userId string) (Integration, error)
	FetchNotionIntegration(id string) (NotionIntegration, error)
	ListByNotionBotId(botId string) ([]NotionIntegration, error)
}

type integrationFetcher struct {
	app core.App
}

func NewIntegrationFetcher(app core.App) IntegrationFetcher {
	return &integrationFetcher{app}
}

func (f *integrationFetcher) FetchById(id string, userId string) (Integration, error) {
	record, err := f.app.Dao().FindRecordById(CollectionIntegration, id)
	if err != nil {
		return nil, err
	}
	integration, err := LoadIntegration(record, f.app)
	if err != nil {
		return nil, err
	}

	if integration.User() != userId {
		slog.Error(
			"Integration user id does not match",
			"integration",
			integration,
			"userId",
			userId,
		)
		return nil, fmt.Errorf("Integration user id does not match")
	}

	return integration, nil
}

func (f *integrationFetcher) FetchNotionIntegration(id string) (NotionIntegration, error) {
	record, err := f.app.Dao().FindRecordById(CollectionIntegration, id)
	if err != nil {
		return nil, err
	}

	integration, err := LoadNotionIntegration(record, f.app)
	if err != nil {
		slog.Error("Error creating notion integration", "err", err)
		return nil, err
	}
	return integration, nil
}

func (f *integrationFetcher) ListByNotionBotId(botId string) ([]NotionIntegration, error) {
	filter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  IntegrationFieldType,
			Op:    filter.OpEquals,
			Value: IntegrationTypeNotion,
		},
		filter.Field{
			Name:  FilterConfigBotId,
			Op:    filter.OpEquals,
			Value: botId,
		},
		filter.Field{
			Name:        IntegrationFieldArchived,
			Op:          filter.OpEquals,
			ValuePreset: filter.ValuePresetNull,
		},
	)
	if err != nil {
		return nil, err
	}
	records, err := f.app.Dao().
		FindRecordsByFilter(CollectionIntegration, filter.Filter, "", 0, 0, filter.Params)
	if err != nil {
		return nil, err
	}

	var integrations []NotionIntegration
	for _, record := range records {
		integration, err := LoadNotionIntegration(record, f.app)
		if err != nil {
			slog.Error("Error creating notion integration", "err", err)
			return nil, err
		}
		integrations = append(integrations, integration)
	}

	return integrations, nil
}
