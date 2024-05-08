package block

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
}
