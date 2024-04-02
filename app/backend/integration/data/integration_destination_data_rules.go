package data

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type IntegrationDestinationDataRules interface {
	ApplyHooks()
}

type integrationDestinationDataRules struct {
	app core.App
}

func NewIntegrationDestinationDataRules(app core.App) IntegrationDestinationDataRules {
	return &integrationDestinationDataRules{app: app}
}

func (h *integrationDestinationDataRules) ApplyHooks() {
	h.immutableFields()
}

func (h *integrationDestinationDataRules) immutableFields() {
	h.app.OnModelBeforeUpdate(CollectionIntegrationDestination).Add(func(e *core.ModelEvent) error {
		updated := NewIntegrationDestinationFromModel(e.Model)
		fetcher := NewIntegrationDestinationFetcher(h.app)
		existing, err := fetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}
		if updated.User() != existing.User() {
			return errors.New("Cannot change user field")
		}
		if updated.Type() != existing.Type() {
			return errors.New("Cannot change type field")
		}
		if updated.DestinationId() != existing.DestinationId() {
			return errors.New("Cannot change destination_id field")
		}
		return nil
	})
}
