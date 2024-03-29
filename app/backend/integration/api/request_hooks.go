package api

import (
	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationRequestHooks interface {
	Apply()
}

type integrationRequestHooks struct {
	app core.App
}

func NewIntegrationRequestHooks(app core.App) IntegrationRequestHooks {
	return &integrationRequestHooks{app: app}
}

func (h *integrationRequestHooks) Apply() {
	h.app.OnRecordBeforeCreateRequest(integ.CollectionIntegration).Add(func(e *core.RecordCreateEvent) error {
		integrationRecord, err := NewIntegration(e.Record)
		if err != nil {
			return err
		}

		var notionIntegration NotionIntegration
		switch i := integrationRecord.(type) {
		case NotionIntegration:
			notionIntegration = i
		default:
			return apis.NewBadRequestError("Invalid integration type", nil)
		}

		config, err := notionIntegration.Config()
		if err != nil {
			return err
		}
		if config.auth.Code == nil {
			return apis.NewBadRequestError("Missing integration config", nil)
		}

		// TODO: Send code to notion

		return nil
	})

}
