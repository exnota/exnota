package block

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type BlockUpdate interface {
	ApplyHooks()
}

type blockUpdate struct {
	app                core.App
	blockFetcher       BlockFetcher
	destinationFetcher DestinationFetcher
}

func NewBlockUpdate(
	app core.App,
	blockFetcher BlockFetcher,
	destinationFetcher DestinationFetcher,
) BlockUpdate {
	return &blockUpdate{app, blockFetcher, destinationFetcher}
}

func (r *blockUpdate) ApplyHooks() {
	r.app.OnModelBeforeUpdate(CollectionBlock).Add(func(e *core.ModelEvent) error {
		updated, err := LoadBlockFromModel(e.Model, r.app)
		if err != nil {
			return err
		}

		existing, err := r.blockFetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}

		// type cannot be changed
		if updated.Type() != existing.Type() {
			return errors.New("Block type cannot be changed")
		}

		// user cannot be changed
		if updated.User() != existing.User() {
			return errors.New("Block user cannot be changed")
		}

		// file cannot be changed
		// If file is changed, PocketBase will delete the previous one.
		if updated.File() != existing.File() {
			return errors.New("Block file cannot be changed")
		}

		// can set destination but not change it
		if updated.Destination() != existing.Destination() {
			if existing.Destination() != "" {
				return errors.New("Block destination cannot be changed")
			}
			destination, err := r.destinationFetcher.FetchById(updated.Destination())
			if err != nil {
				return err
			}

			if updated.User() != destination.User() {
				return errors.New("Block user does not match destination user")
			}
		}

		return nil
	})

}
