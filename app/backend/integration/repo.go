package integration

import (
	"time"

	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationFetcher interface {
	FetchById(request FetchByIdRequest) (Integration, error)
	FetchNotionIntegration(id string) (NotionIntegration, error)
	ListByNotionBotId(botId string) ([]NotionIntegration, error)
}

type FetchByIdRequest struct {
	IntegrationId string `validate:"min=1"`
	UserId        string `validate:"min=1"`
}

type IntegrationDestinationFetcher interface {
	FetchById(id string) (IntegrationDestination, error)
	FetchByDestinationID(destinationId string) (IntegrationDestination, error)
	ListByExternalID(externalRecordId string) ([]IntegrationDestination, error)
	ListByDestinationIDs(destinationIds []string) ([]IntegrationDestination, error)
}

type IntegrationNotionObjectFetcher interface {
	FetchById(id string) (IntegrationNotionObject, error)
	// Returns wrapped sql.ErrNoRows if not found.
	FetchByExternalID(request NotionObjectFetchRequest) (IntegrationNotionObject, error)
	ListByIds(ids []string) ([]IntegrationNotionObject, error)
}

type IntegrationNotionObjectWriter interface {
	// Loads or creates a record, validates it, but does not persist.
	CreateUpsertRecord(request NotionObjectCreateRequest) (*models.Record, error)
	UpdateConnected(request NotionUpdateSyncConnectedRequest) error
	UpdateErrored(request NotionUpdateSyncErrorRequest) error
	UpdateArchived(request NotionUpdateSyncArchivedRequest) error
}

type NotionObjectCreateRequest struct {
	ExternalId string                     `validate:"required"`
	Type       lib_integ.NotionObjectType `validate:"required"`
	Title      string                     `validate:"required"`
	Properties any                        `validate:"required"`
	User       string                     `validate:"required"`
}

type NotionObjectFetchRequest struct {
	ExternalID string                     `validate:"min=1"`
	Type       lib_integ.NotionObjectType `validate:"required"`
	User       string                     `validate:"min=1"`
}

type NotionUpdateSyncConnectedRequest struct {
	Id         string    `validate:"min=1"`
	Title      string    `validate:"required"`
	Properties any       `validate:"required"`
	LastSynced time.Time `validate:"required"`
}

type NotionUpdateSyncErrorRequest struct {
	Id         string                       `validate:"min=1"`
	Status     lib_integ.NotionObjectStatus `validate:"required"`
	LastSynced time.Time                    `validate:"required"`
}

type NotionUpdateSyncArchivedRequest struct {
	Id         string    `validate:"min=1"`
	Title      string    `validate:"required"`
	Properties any       `validate:"required"`
	LastSynced time.Time `validate:"required"`
}
