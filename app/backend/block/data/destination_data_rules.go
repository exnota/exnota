package data

import (
	"errors"

	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/core"
)

type DestinationDataRules interface {
	ApplyHooks()
}

type destinationDataRules struct {
	app core.App
}

func NewDestinationDataRules(app core.App) DestinationDataRules {
	return &destinationDataRules{app}
}

func (r *destinationDataRules) ApplyHooks() {
	r.immutableRules()
}

func (r *destinationDataRules) immutableRules() {
	r.app.OnModelBeforeUpdate(block.CollectionDestination).Add(func(e *core.ModelEvent) error {
		updated, err := block.NewDestination(e.Model, r.app)
		if err != nil {
			return err
		}
		fetcher := NewDestinationFetcher(r.app)
		existing, err := fetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}

		if updated.User() != existing.User() {
			return errors.New("Cannot change user")
		}
		if updated.Workspace() != existing.Workspace() {
			return errors.New("Cannot change workspace")
		}

		return nil
	})
}
