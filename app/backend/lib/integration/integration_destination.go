package integration

type IntegrationDestinationEventListener func(event IntegrationDestinationEvent) error

type IntegrationDestinationEvent struct {
	Prev IntegrationDestinationState
	Next IntegrationDestinationState
}

type IntegrationDestinationState struct {
	Name         string
	NotionStatus IntegrationDestinationNotionStatus
}

type IntegrationDestinationNotionStatus string

const (
	IntegrationDestinationNotionStatusConnected IntegrationDestinationNotionStatus = "connected"
	IntegrationDestinationNotionStatusNotFound  IntegrationDestinationNotionStatus = "not-found"
	IntegrationDestinationNotionStatusArchived  IntegrationDestinationNotionStatus = "archived"
	IntegrationDestinationNotionStatusError     IntegrationDestinationNotionStatus = "error"
)
