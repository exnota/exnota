package block

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type BlockDataRules interface {
	ApplyHooks()
}

type blockDataRules struct {
	app                core.App
	blockFetcher       BlockFetcher
	destinationFetcher DestinationFetcher
}

func NewBlockDataRules(
	app core.App,
	blockFetcher BlockFetcher,
	destinationFetcher DestinationFetcher,
) BlockDataRules {
	return &blockDataRules{app, blockFetcher, destinationFetcher}
}

func (r *blockDataRules) ApplyHooks() {
	r.relationRules()
	r.immutableRules()
}

func (r *blockDataRules) relationRules() {
	// user must match destination's user
	r.app.OnModelBeforeCreate(CollectionBlock).Add(func(e *core.ModelEvent) error {
		block, err := LoadBlockFromModel(e.Model, r.app)
		if err != nil {
			return err
		}

		destination, err := r.destinationFetcher.FetchById(block.Destination())
		if err != nil {
			return err
		}

		if block.User() != destination.User() {
			return errors.New("Block user does not match destination user")
		}

		return nil
	})
}

func (r *blockDataRules) immutableRules() {
	// type cannot be changed
	r.app.OnModelBeforeUpdate(CollectionBlock).Add(func(e *core.ModelEvent) error {
		updated, err := LoadBlockFromModel(e.Model, r.app)
		if err != nil {
			return err
		}

		existing, err := r.blockFetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}

		if updated.Type() != existing.Type() {
			return errors.New("Block type cannot be changed")
		}

		return nil
	})

	// user cannot be changed
	r.app.OnModelBeforeUpdate(CollectionBlock).Add(func(e *core.ModelEvent) error {
		updated, err := LoadBlockFromModel(e.Model, r.app)
		if err != nil {
			return err
		}

		existing, err := r.blockFetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}

		if updated.User() != existing.User() {
			return errors.New("Block user cannot be changed")
		}

		return nil
	})

	// file cannot be changed
	// If file is changed, PocketBase will delete the previous one.
	r.app.OnModelBeforeUpdate(CollectionBlock).Add(func(e *core.ModelEvent) error {
		updated, err := LoadBlockFromModel(e.Model, r.app)
		if err != nil {
			return err
		}

		existing, err := r.blockFetcher.FetchById(updated.Id())
		if err != nil {
			return err
		}

		if updated.File() != existing.File() {
			return errors.New("Block file cannot be changed")
		}

		return nil
	})

	// user must match destination's user
	r.app.OnModelBeforeCreate(CollectionBlock).Add(func(e *core.ModelEvent) error {
		block, err := LoadBlockFromModel(e.Model, r.app)
		if err != nil {
			return err
		}

		destination, err := r.destinationFetcher.FetchById(block.Destination())
		if err != nil {
			return err
		}

		if block.User() != destination.User() {
			return errors.New("Block user does not match destination user")
		}

		return nil
	})

}
