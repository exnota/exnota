package integration

type GetSuggestedIntegrationDestinations func(request GetSuggestedDestinationsRequest) (*GetSuggestedDestinationsResponse, error)

type GetSuggestedDestinationsRequest struct {
	IntegrationID string
	UserID        string
	WorkspaceType WorkspaceType `validate:"required,oneof=database custom"`
}

type WorkspaceType string

const (
	WorkspaceTypeDatabase WorkspaceType = "database"
	WorkspaceTypeCustom   WorkspaceType = "custom"
)

type GetSuggestedDestinationsResponse struct {
	NotionDestinations []NotionDestination `json:"notion_destinations" validate:"required"`
}

type NotionDestination struct {
	Name   string       `json:"name"           validate:"required"`
	Object NotionObject `json:"object"         validate:"required"`
	Icon   *NotionIcon  `json:"icon,omitempty"`
}
