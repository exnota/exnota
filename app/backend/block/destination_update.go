package block

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type DestinationUpdate interface {
	ApplyHooks()
}

type destinationUpdate struct {
	app                core.App
	destinationFetcher DestinationFetcher
}

func NewDestinationUpdate(
	app core.App,
	destinationFetcher DestinationFetcher,
) DestinationUpdate {
	return &destinationUpdate{app, destinationFetcher}
}

func (r *destinationUpdate) ApplyHooks() {
	r.app.OnModelBeforeUpdate(CollectionDestination).Add(func(e *core.ModelEvent) error {
		updated, err := LoadDestination(e.Model, r.app)
		if err != nil {
			return err
		}
		existing, err := r.destinationFetcher.FetchById(updated.Id())
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
