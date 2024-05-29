package block

import "exnota.com/backend/lib/integration"

// Interfaces shared between domains

type CreateDestinationSyncRequest struct {
	DestinationId string
	IntegrationId string
	Config        map[string]interface{}
	User          string
}

type DestinationExternalRecordType string

const (
	DestinationExternalRecordTypeNotion DestinationExternalRecordType = "notion"
)

type CreateDestinationSyncResult struct {
	DestinationId      string
	DestinationName    string
	ExternalRecordType DestinationExternalRecordType
	ExternalRecordId   string
	NotionStatus       integration.NotionObjectStatus
}

type GetDestinationForExternalRequest struct {
	IntegrationId string                 `validate:"min=1"`
	UserId        string                 `validate:"min=1"`
	Config        map[string]interface{} `validate:"required"`
}
