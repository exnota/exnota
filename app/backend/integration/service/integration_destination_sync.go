package service

import (
	"errors"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service/notion"
	"exnota.com/backend/lib/block"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

type IntegrationDestinationSync interface {
	Sync(request block.DestinationSyncRequest) (result *block.DestinationSyncResult, err error)
}

type integrationDestinationSync struct {
	app core.App
}

func NewIntegrationDestinationSync(app core.App) IntegrationDestinationSync {
	return &integrationDestinationSync{app}
}

func (s *integrationDestinationSync) Sync(request block.DestinationSyncRequest) (result *block.DestinationSyncResult, err error) {
	fetcher := data.NewIntegrationFetcher(s.app)
	integration, err := fetcher.FetchById(request.IntegrationId, request.User)
	if err != nil {
		return nil, err
	}

	var destinationResult *block.DestinationSyncResult
	switch integration.Type() {
	case data.TypeNotion:
		notionSync := notion.NewNotionSync(s.app)
		var externalRecord *models.Record
		destinationResult, externalRecord, err = notionSync.Sync(notion.NotionSyncRequest{
			DestinationId: request.DestinationId,
			Config:        request.Config,
			User:          request.User,
			IntegrationId: request.IntegrationId,
		})
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
