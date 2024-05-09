package data

import (
	"database/sql"
	"log/slog"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationBlockNotionMappingFetcher interface {
	FetchByInternalBlockId(
		internalBlockId string,
	) (integ.IntegrationBlockNotionMapping, error)
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
) (integ.IntegrationBlockNotionMapping, error) {
	filter, err := filter.CreateAndFilter(filter.Field{
		Name:  integ.BlockNotionMappingFieldInternalBlock,
		Op:    filter.OpEquals,
		Value: internalBlockId,
	})
	if err != nil {
		return nil, err
	}

	record, err := f.app.Dao().
		FindFirstRecordByFilter(integ.CollectionIntegrationBlockNotionMapping,
			filter.Filter, filter.Params,
		)
	if err == sql.ErrNoRows {
		return nil, nil
	} else if err != nil {
		return nil, err
	}
	mapping, err := integ.LoadIntegrationBlockNotionMapping(record, f.app)
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
