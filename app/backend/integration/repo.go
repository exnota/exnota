package integration

import (
	"time"

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
	ListByDestinationIds(destinationIds []string) ([]IntegrationDestination, error)
}

type IntegrationNotionObjectFetcher interface {
	FetchById(id string) (IntegrationNotionObject, error)
	ListByIds(ids []string) ([]IntegrationNotionObject, error)
}

type IntegrationNotionObjectWriter interface {
	// Loads or creates a record, validates it, but does not persist.
	CreateUpsertRecord(request CreateRequest) (*models.Record, error)
	UpdateConnected(request UpdateSyncConnectedRequest) error
	UpdateErrored(request UpdateSyncErrorRequest) error
	UpdateArchived(request UpdateSyncArchivedRequest) error
}

type CreateRequest struct {
	ExternalId string                      `validate:"required"`
	Type       IntegrationNotionObjectType `validate:"required"`
	Properties any                         `validate:"required"`
	User       string                      `validate:"required"`
}

type UpdateSyncConnectedRequest struct {
	Id         string    `validate:"min=1"`
	Properties any       `validate:"required"`
	LastSynced time.Time `validate:"required"`
}

type UpdateSyncErrorRequest struct {
	Id         string                        `validate:"min=1"`
	Status     IntegrationNotionObjectStatus `validate:"required"`
	LastSynced time.Time                     `validate:"required"`
}

type UpdateSyncArchivedRequest struct {
	Id         string    `validate:"min=1"`
	Properties any       `validate:"required"`
	LastSynced time.Time `validate:"required"`
}
