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
	FetchByDestinationId(destinationId string) (IntegrationDestination, error)
	FetchByExternalId(externalRecordId string) (IntegrationDestination, error)
	ListByDestinationIds(destinationIds []string) ([]IntegrationDestination, error)
}

type IntegrationNotionObjectFetcher interface {
	FetchById(id string) (IntegrationNotionObject, error)
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
	ExternalId string                      `validate:"required"`
	Type       IntegrationNotionObjectType `validate:"required"`
	Title      string                      `validate:"required"`
	Properties any                         `validate:"required"`
	User       string                      `validate:"required"`
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
