package usecase

import (
	"errors"
	"log/slog"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion"
	"exnota.com/backend/lib/block"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationDestinationSync interface {
	CreateSync(
		request block.CreateDestinationSyncRequest,
	) (result *block.CreateDestinationSyncResult, err error)
	UpdateSync(request UpdateSyncRequest) error
}

type DestinationFetcher interface {
	ListIdsByIntegrationId(workspaceIntegrationId string) ([]string, error)
}

type integrationDestinationSync struct {
	app                           core.App
	integrationFetcher            data.IntegrationFetcher
	integrationDestinationFetcher data.IntegrationDestinationFetcher
	destinationFetcher            DestinationFetcher
}

func NewIntegrationDestinationSync(
	app core.App,
	integrationFetcher data.IntegrationFetcher,
	integrationDestinationFetcher data.IntegrationDestinationFetcher,
	destinationFetcher DestinationFetcher,
) IntegrationDestinationSync {
	return &integrationDestinationSync{
		app,
		integrationFetcher,
		integrationDestinationFetcher,
		destinationFetcher,
	}
}

func (s *integrationDestinationSync) CreateSync(
	request block.CreateDestinationSyncRequest,
) (result *block.CreateDestinationSyncResult, err error) {
	integration, err := s.integrationFetcher.FetchById(data.FetchByIdRequest{
		IntegrationId: request.IntegrationId,
		UserId:        request.User,
	})
	if err != nil {
		return nil, err
	}

	var destinationResult *block.CreateDestinationSyncResult
	switch integration.Type() {
	case data.TypeNotion:
		notionSync := notion.NewNotionDestinationSync(
			s.app,
			data.NewIntegrationNotionObjectFetcher(s.app),
		)
		var externalRecord *models.Record
		destinationResult, externalRecord, err = notionSync.CreateSync(
			notion.CreateNotionDestinationSyncRequest{
				DestinationId: request.DestinationId,
				Config:        request.Config,
				User:          request.User,
				IntegrationId: request.IntegrationId,
			},
		)
		if err != nil {
			return nil, err
		}

		err = s.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
			// Persist Notion object in transaction
			externalRecordForm := forms.NewRecordUpsert(s.app, externalRecord)
			err = externalRecordForm.Validate()
			if err != nil {
				return err
			}
			externalRecordForm.SetDao(txDao)
			err = externalRecordForm.Submit()
			if err != nil {
				return err
			}

			// Persist integration destination in transaction
			writer := data.NewIntegrationDestinationWriter(s.app, txDao)
			err = writer.Upsert(data.IntegrationDestinationUpsertData{
				DestinationId:      request.DestinationId,
				ExternalRecordType: data.IntegrationDestinationRecordTypeNotion,
				ExternalRecordId:   externalRecord.Id,
				User:               request.User,
			})
			if err != nil {
				return err
			}

			return nil
		})
		if err != nil {
			return nil, err
		}

	default:
		return nil, errors.New("Integration type not supported")
	}

	return destinationResult, nil
}

type UpdateSyncRequest struct {
	IntegrationId string `validate:"min=1"`
	UserId        string `validate:"min=1"`
}

func (s *integrationDestinationSync) UpdateSync(request UpdateSyncRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	integration, err := s.integrationFetcher.FetchById(data.FetchByIdRequest{
		IntegrationId: request.IntegrationId,
		UserId:        request.UserId,
	})
	if err != nil {
		return err
	}
	if integration.Status() != data.IntegrationStatusConnected {
		slog.Warn("Integration not connected", "integrationId", request.IntegrationId)
		return nil
	}

	destinationIds, err := s.destinationFetcher.ListIdsByIntegrationId(request.IntegrationId)
	if err != nil {
		return err
	}
	if len(destinationIds) == 0 {
		slog.Info("No destinations for integration", "integrationId", request.IntegrationId)
		return nil
	}

	// TODO: Remove
	slog.Info("Destination IDs", "destinationIds", destinationIds)

	integrationDestinations, err := s.integrationDestinationFetcher.ListByDestinationIds(
		destinationIds,
	)
	if err != nil {
		return err
	}

	externalRecordIds := make([]string, len(integrationDestinations))
	for i, destination := range integrationDestinations {
		externalRecordIds[i] = destination.ExternalRecordId()
	}

	// TODO: Remove
	slog.Info("Integration destinations", "num", len(integrationDestinations))

	switch integration.Type() {
	case data.TypeNotion:
		notionSync := notion.NewNotionDestinationSync(
			s.app,
			data.NewIntegrationNotionObjectFetcher(s.app),
		)
		err = notionSync.UpdateSync(notion.UpdateSyncRequest{
			IntegrationId:     request.IntegrationId,
			ExternalRecordIds: externalRecordIds,
		})
		if err != nil {
			return err
		}
	default:
		return errors.New("Integration type not supported")
	}

	return nil

}
