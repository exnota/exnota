package block

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
)

type BlockCreate interface {
	ApplyHooks()
}

type blockCreate struct {
	app                core.App
	destinationFetcher DestinationFetcher
}

func NewBlockCreate(
	app core.App,
	destinationFetcher DestinationFetcher,
) BlockCreate {
	return &blockCreate{app, destinationFetcher}
}

func (r *blockCreate) ApplyHooks() {
	// user must match destination's user
	r.app.OnModelBeforeCreate(CollectionBlock).Add(func(e *core.ModelEvent) error {
		block, err := LoadBlockFromModel(e.Model, r.app)
		if err != nil {
			return err
		}

		// if destination is set, user must match destination's user
		if block.Destination() != "" {
			destination, err := r.destinationFetcher.FetchById(block.Destination())
			if err != nil {
				return err
			}

			if block.User() != destination.User() {
				return errors.New("Block user does not match destination user")
			}
		}

		return nil
	})
}
