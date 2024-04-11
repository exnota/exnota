package data

import (
	"log/slog"

	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationBlockNotionMappingFetcher interface {
	FetchByInternalBlockId(internalBlockId string) (IntegrationBlockNotionMapping, error)
}

type integrationBlockNotionMappingFetcher struct {
	app core.App
}

func NewIntegrationBlockNotionMappingFetcher(app core.App) IntegrationBlockNotionMappingFetcher {
	return &integrationBlockNotionMappingFetcher{
		app: app,
	}
}

func (f *integrationBlockNotionMappingFetcher) FetchByInternalBlockId(
	internalBlockId string,
) (IntegrationBlockNotionMapping, error) {
	filter, err := filter.CreateAndFilter(filter.Field{
		Name:  BlockNotionMappingFieldInternalBlock,
		Op:    filter.OpEquals,
		Value: internalBlockId,
	})
	if err != nil {
		return nil, err
	}

	record, err := f.app.Dao().FindFirstRecordByFilter(CollectionIntegrationBlockNotionMapping,
		filter.Filter, filter.Params,
	)
	if err != nil {
		return nil, err
	}
	mapping, err := NewIntegrationBlockNotionMapping(record, f.app)
	if err != nil {
		slog.Error(
			"Failed to create IntegrationBlockNotionMapping instance after fetching",
			"internalBlockId",
			internalBlockId,
			"error",
			err,
		)
		return nil, err
	}
	return mapping, nil
}
