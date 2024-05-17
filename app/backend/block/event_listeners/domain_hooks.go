package event_listeners

import "github.com/pocketbase/pocketbase/core"

// Applies all internal block domain hooks
func ApplyBlockDomainHooks(app core.App) {
	NewArchiveWorkspaceDestinations(app).ApplyHooks()
}
