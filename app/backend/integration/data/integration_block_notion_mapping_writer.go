package data

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type IntegrationBlockNotionMappingWriter interface {
	Create(request CreateMappingRequest) error
	Update(request UpdateMappingRequest) error
}

type integrationBlockNotionMappingWriter struct {
	app core.App
}

type CreateMappingRequest struct {
	BlockType           BlockType           `validate:"required"`
	InternalBlock       string              `validate:"required"`
	InternalDestination string              `validate:"required"`
	ExternalBlock       string              `validate:"required"`
	ExternalDestination string              `validate:"required"`
	ExternalUrl         string              `validate:"required"`
	Config              *BlockMappingConfig `validate:"required"`
}

func NewIntegrationBlockNotionMappingWriter(app core.App) IntegrationBlockNotionMappingWriter {
	return &integrationBlockNotionMappingWriter{
		app: app,
	}
}

func (w *integrationBlockNotionMappingWriter) Create(
	request CreateMappingRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	mapping, err := CreateIntegrationBlockNotionMapping(w.app)
	if err != nil {
		return err
	}

	mapping.SetBlockType(request.BlockType)
	mapping.SetInternalBlock(request.InternalBlock)
	mapping.SetInternalDestination(request.InternalDestination)
	mapping.SetExternalBlock(request.ExternalBlock)
	mapping.SetExternalDestination(request.ExternalDestination)
	mapping.SetExternalUrl(request.ExternalUrl)
	err = mapping.SetConfig(request.Config)
	if err != nil {
		return err
	}

	return w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		err = mapping.ValidateAndSubmit(txDao)
		if err != nil {
			return err
		}
		return nil
	})
}

type UpdateMappingRequest struct {
	InternalBlock string              `validate:"required"`
	Config        *BlockMappingConfig `validate:"required"`
}

func (w *integrationBlockNotionMappingWriter) Update(
	request UpdateMappingRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	txErr := w.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		filter, err := filter.CreateAndFilter(
			filter.Field{
				Name:  BlockNotionMappingFieldInternalBlock,
				Op:    filter.OpEquals,
				Value: request.InternalBlock,
			},
		)
		if err != nil {
			return err
		}

		mappings, err := w.app.Dao().FindRecordsByFilter(
			CollectionIntegrationBlockNotionMapping,
			filter.Filter,
			"-created", 1, 0,
			filter.Params)
		if err != nil {
			return err
		}
		if len(mappings) == 0 {
			slog.Error("Mapping not found", "internal_block", request.InternalBlock)
			return fmt.Errorf("Mapping not found")
		}
		if len(mappings) > 1 {
			slog.Error("Multiple mappings found", "internal_block", request.InternalBlock)
			return fmt.Errorf("Multiple mappings found")
		}

		mapping, err := LoadIntegrationBlockNotionMapping(mappings[0], w.app)
		if err != nil {
			return err
		}

		err = mapping.SetConfig(request.Config)
		if err != nil {
			return err
		}

		err = mapping.ValidateAndSubmit(txDao)
		if err != nil {
			return err
		}
		return nil
	})
	return txErr
}
