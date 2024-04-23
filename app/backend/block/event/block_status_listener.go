package event

import (
	"exnota.com/backend/block/data"
	notion_mapping_data "exnota.com/backend/integration/data"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

// TODO: Plan
// - Listen to block job events
//   - if it's a status change
//   - get all jobs for the same block
//   - separate 'error' into 'error-no-retry' and 'error-will-retry'
//   - if all complete -> external.exportStatus = complete
//   - if all either error-will-retry, complete, or waiting -> external.exportStatus = in progress
//   - if at least one is error-no-retry -> external.exportStatus = error

type BlockStatusListener interface {
	ApplyHooks()
}

type blockStatusListener struct {
	app core.App
}

func NewBlockStatusListener(app core.App) BlockStatusListener {
	return &blockStatusListener{
		app: app,
	}
}

func (l *blockStatusListener) ApplyHooks() {
	l.setExternalUrl()
}

func (l *blockStatusListener) setExternalUrl() {
	// On Notion mapping create, update external URL if already set
	l.app.OnModelAfterCreate(
		notion_mapping_data.CollectionIntegrationBlockNotionMapping).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			mapping, err := notion_mapping_data.LoadIntegrationBlockNotionMapping(record, l.app)
			if err != nil {
				return err
			}

			if mapping.ExternalUrl() == "" {
				return nil
			}

			writer := data.NewBlockWriter(l.app)
			err = writer.SetExternalUrl(mapping.InternalBlock(), mapping.ExternalUrl())
			if err != nil {
				return err
			}

			return nil
		},
	)

	// On Notion mapping update, update external URL if it has changed
	l.app.OnModelAfterUpdate(
		notion_mapping_data.CollectionIntegrationBlockNotionMapping).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			newMapping, err := notion_mapping_data.LoadIntegrationBlockNotionMapping(record, l.app)
			if err != nil {
				return err
			}

			prevMapping, err := notion_mapping_data.LoadIntegrationBlockNotionMapping(
				record.OriginalCopy(),
				l.app,
			)
			if err != nil {
				return err
			}

			if prevMapping.ExternalUrl() != newMapping.ExternalUrl() {
				writer := data.NewBlockWriter(l.app)
				err = writer.SetExternalUrl(newMapping.InternalBlock(), newMapping.ExternalUrl())
				if err != nil {
					return err
				}
			}

			return nil
		},
	)
}
