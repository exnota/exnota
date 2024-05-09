package integration

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type IntegrationDestinationDataRules interface {
	ApplyHooks()
}

type integrationDestinationDataRules struct {
	app                           core.App
	integrationDestinationFetcher IntegrationDestinationFetcher
}

func NewIntegrationDestinationDataRules(
	app core.App,
	integrationDestinationFetcher IntegrationDestinationFetcher,
) IntegrationDestinationDataRules {
	return &integrationDestinationDataRules{app, integrationDestinationFetcher}
}

func (h *integrationDestinationDataRules) ApplyHooks() {
	h.immutableFields()
}

func (h *integrationDestinationDataRules) immutableFields() {
	h.app.OnModelBeforeUpdate(CollectionIntegrationDestination).Add(func(e *core.ModelEvent) error {
		updated := NewIntegrationDestinationFromModel(e.Model)
		existing, err := h.integrationDestinationFetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}
		if updated.User() != existing.User() {
			return errors.New("Cannot change user field")
		}
		if updated.ExternalRecordType() != existing.ExternalRecordType() {
			return errors.New("Cannot change type field")
		}
		if updated.DestinationId() != existing.DestinationId() {
			return errors.New("Cannot change destination_id field")
		}
		return nil
	})
}
