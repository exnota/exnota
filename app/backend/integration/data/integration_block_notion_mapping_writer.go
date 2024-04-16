package data

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type IntegrationBlockNotionMappingWriter interface {
	Create(request CreateMappingRequest) error
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
