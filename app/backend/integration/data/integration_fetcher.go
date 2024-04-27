package data

import (
	"fmt"
	"log/slog"

	"github.com/pocketbase/pocketbase/core"
)

type IntegrationFetcher interface {
	FetchById(id string, userId string) (Integration, error)
	FetchNotionIntegration(id string) (NotionIntegration, error)
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
		slog.Error("Integration user id does not match", "integration", integration, "userId", userId)
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
