package integration

type GetSuggestedIntegrationDestinations func(request GetSuggestedDestinationsRequest) (*Destinations, error)

type GetSuggestedDestinationsRequest struct {
	IntegrationID string
	UserID        string
	WorkspaceType WorkspaceType `validate:"omitempty,oneof=database custom"`
}

type WorkspaceType string

const (
	WorkspaceTypeDatabase WorkspaceType = "database"
	WorkspaceTypeCustom   WorkspaceType = "custom"
)
