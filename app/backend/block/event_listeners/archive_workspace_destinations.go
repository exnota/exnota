package event_listeners

import (
	"log/slog"

	"exnota.com/backend/block"
	"exnota.com/backend/block/data"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type ArchiveWorkspaceDestinations interface {
	ApplyHooks()
}

type archiveWorkspaceDestinations struct {
	app core.App
}

func NewArchiveWorkspaceDestinations(app core.App) ArchiveWorkspaceDestinations {
	return &archiveWorkspaceDestinations{
		app: app,
	}
}

func (l *archiveWorkspaceDestinations) ApplyHooks() {
	l.app.OnModelAfterUpdate(
		block.CollectionWorkspace).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			nextWorkspace, err := block.LoadWorkspace(record, l.app)
			if err != nil {
				return err
			}

			prevWorkspace, err := block.LoadWorkspace(record.OriginalCopy(), l.app)
			if err != nil {
				return err
			}

			// If workspace archived, archive all destinations
			if prevWorkspace.Archived().IsZero() && !nextWorkspace.Archived().IsZero() {
				slog.Info(
					"Workspace archived. Archiving destinations",
					"workspace",
					nextWorkspace.Id(),
				)
				destinationWriter := data.NewDestinationWriter(l.app)
				err = destinationWriter.ArchiveForWorkspace(nextWorkspace.Id())
				if err != nil {
					return err
				}
			}

			return nil
		},
	)
}
