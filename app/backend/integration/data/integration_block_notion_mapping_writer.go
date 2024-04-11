package data

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type IntegrationBlockNotionMappingWriter interface {
	CreateVoiceNoteMapping(request VoiceNoteMappingRequest) error
}

type integrationBlockNotionMappingWriter struct {
	app core.App
}

type VoiceNoteMappingRequest struct {
	Id                  string                  `validate:"required"`
	Type                BlockNotionMappingType  `validate:"required"`
	InternalBlock       string                  `validate:"required"`
	InternalDestination string                  `validate:"required"`
	ExternalBlock       string                  `validate:"required"`
	ExternalDestination string                  `validate:"required"`
	ExternalUrl         string                  `validate:"required"`
	Config              *VoiceNoteMappingConfig `validate:"required"`
}

func NewIntegrationBlockNotionMappingWriter(app core.App) IntegrationBlockNotionMappingWriter {
	return &integrationBlockNotionMappingWriter{
		app: app,
	}
}

func (w *integrationBlockNotionMappingWriter) CreateVoiceNoteMapping(request VoiceNoteMappingRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	mapping, err := CreateVoiceNoteMapping(w.app)
	if err != nil {
		return err
	}

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
