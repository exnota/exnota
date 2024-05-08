package block

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type BlockUpdate interface {
	ApplyHooks()
}

type blockUpdate struct {
	app          core.App
	blockFetcher BlockFetcher
}

func NewBlockUpdate(
	app core.App,
	blockFetcher BlockFetcher,
) BlockUpdate {
	return &blockUpdate{app, blockFetcher}
}

func (r *blockUpdate) ApplyHooks() {
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
}
