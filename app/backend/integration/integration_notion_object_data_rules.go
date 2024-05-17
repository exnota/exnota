package integration

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type IntegrationNotionObjectDataRules interface {
	ApplyHooks()
}

type integrationNotionObjectDataRules struct {
	app                            core.App
	integrationNotionObjectFetcher IntegrationNotionObjectFetcher
}

func NewIntegrationNotionObjectHooks(
	app core.App,
	integrationNotionObjectFetcher IntegrationNotionObjectFetcher,
) IntegrationNotionObjectDataRules {
	return &integrationNotionObjectDataRules{app, integrationNotionObjectFetcher}
}

func (h *integrationNotionObjectDataRules) ApplyHooks() {
	h.immutableFields()
}

func (h *integrationNotionObjectDataRules) immutableFields() {
	h.app.OnModelBeforeUpdate(CollectionIntegrationNotionObject).
		Add(func(e *core.ModelEvent) error {
			updated := LoadIntegrationNotionObjectFromModel(e.Model)
			existing, err := h.integrationNotionObjectFetcher.FetchById(updated.ID())
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
			if updated.ExternalID() != existing.ExternalID() {
				return errors.New("Cannot change external_id")
			}

			return nil
		})
}
