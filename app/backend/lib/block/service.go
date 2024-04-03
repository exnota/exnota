package block

// Interfaces shared between domains

type DestinationSyncRequest struct {
	DestinationId string
	IntegrationId string
	Config        map[string]interface{}
	User          string
}

type DestinationExternalRecordType string

const (
	DestinationExternalRecordTypeNotion DestinationExternalRecordType = "notion"
)

type DestinationSyncResult struct {
	DestinationId      string
	DestinationName    string
	ExternalRecordType DestinationExternalRecordType
	ExternalRecordId   string
}
