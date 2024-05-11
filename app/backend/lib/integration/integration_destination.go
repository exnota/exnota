package integration

type IntegrationDestinationEventListener func(event IntegrationDestinationEvent) error

type IntegrationDestinationEvent struct {
	Id   string                      `validate:"min=1"`
	Prev IntegrationDestinationState `validate:"required"`
	Next IntegrationDestinationState `validate:"required"`
}

type IntegrationDestinationState struct {
	// Old data may not have a name (e.g. Notion objects may not have a title)
	Name               string
	NotionObjectStatus NotionObjectStatus `validate:"required,oneof=connected not-found archived unknown-error rate-limited"`
}

// Status is the same for Destination and Block mappings for the Notion
// integration.
type NotionObjectStatus string

const (
	// When updating these statuses, make sure to update the validation above.
	NotionObjectStatusConnected NotionObjectStatus = "connected"
	// This can mean access was revoked or the object was deleted.
	NotionObjectStatusNotFound     NotionObjectStatus = "not-found"
	NotionObjectStatusArchived     NotionObjectStatus = "archived"
	NotionObjectStatusUnknownError NotionObjectStatus = "unknown-error"
	NotionObjectStatusRateLimited  NotionObjectStatus = "rate-limited"
)
