package data

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type IntegrationNotionObjectDataRules interface {
	ApplyHooks()
}

type integrationNotionObjectDataRules struct {
	app core.App
}

func NewIntegrationNotionObjectHooks(app core.App) IntegrationNotionObjectDataRules {
	return &integrationNotionObjectDataRules{app: app}
}

func (h *integrationNotionObjectDataRules) ApplyHooks() {
	h.immutableFields()
}

func (h *integrationNotionObjectDataRules) immutableFields() {
	h.app.OnModelBeforeUpdate(CollectionIntegrationNotionObject).
		Add(func(e *core.ModelEvent) error {
			updated := LoadIntegrationNotionObjectFromModel(e.Model)
			fetcher := NewIntegrationNotionObjectFetcher(h.app)
			existing, err := fetcher.FetchById(updated.Id())
			if err != nil {
				return err
			}
			if existing == nil {
				return errors.New("Notion object does not exist")
			}

			if updated.User() != existing.User() {
				return errors.New("Cannot change user")
			}
			if updated.Type() != existing.Type() {
				return errors.New("Cannot change type")
			}
			if updated.ExternalId() != existing.ExternalId() {
				return errors.New("Cannot change external_id")
			}

			return nil
		})
}
