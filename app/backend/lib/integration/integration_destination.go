package integration

type IntegrationDestinationEventListener func(event IntegrationDestinationEvent) error

type IntegrationDestinationEvent struct {
	Prev IntegrationDestinationState
	Next IntegrationDestinationState
}

type IntegrationDestinationState struct {
	Name               string
	NotionObjectStatus NotionObjectStatus
}

// Status is the same for Destination and Block mappings for the Notion
// integration.
type NotionObjectStatus string

const (
	NotionObjectStatusConnected NotionObjectStatus = "connected"
	// This can mean access was revoked or the object was deleted.
	NotionObjectStatusNotFound     NotionObjectStatus = "not-found"
	NotionObjectStatusArchived     NotionObjectStatus = "archived"
	NotionObjectStatusUnknownError NotionObjectStatus = "unknown-error"
	NotionObjectStatusRateLimited  NotionObjectStatus = "rate-limited"
)
