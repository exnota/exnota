package job

import (
	"fmt"
	"log/slog"
	"reflect"

	block_data "exnota.com/backend/block/data"
	integ_data "exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service/notion"
	"exnota.com/backend/job/data"
	"github.com/pocketbase/pocketbase/core"
)

type ExportJobRunner interface {
	RunnableBlockJob
}

type exportJobRunnerConfig struct {
	app core.App
}

func NewExportJobRunner(app core.App) ExportJobRunner {
	return &exportJobRunnerConfig{
		app: app,
	}
}

func (j *exportJobRunnerConfig) Run(genericJob data.BlockJob, app core.App) (data.Summary, error) {
	genericExportJob, err := data.NewExportBlockJob(genericJob.Record(), app)
	if err != nil {
		return nil, err
	}

	switch job := genericExportJob.(type) {
	case data.CreateVoiceNoteJob:
		slog.Info("Running create voice note job", "jobId", genericJob.ID())

		// Get integration info
		configData, err := job.ConfigData()
		if err != nil {
			return nil, err
		}
		genericIntegration, err := j.integrationForDestination(configData.DestinationId, job.User())
		if err != nil {
			return nil, err
		}

		// Complete job if destination isn't integrated
		if genericIntegration == nil {
			slog.Info("No integration for destination", "destinationId", configData.DestinationId)
			return data.NewSummaryComplete(
				"No integration for destination " + configData.DestinationId,
			), nil
		}

		// Get external record id
		externalRecordId, err := j.getExternalRecordId(configData.DestinationId)
		if err != nil {
			return nil, err
		}

		// Call appropriate integration type handler
		switch integration := genericIntegration.(type) {
		case integ_data.NotionIntegration:
			slog.Info("Running create voice note job for Notion", "job", genericJob)

			files := make([]notion.CreateVoiceNotePageRequestFile, len(configData.Files))
			for i, file := range configData.Files {
				files[i] = notion.CreateVoiceNotePageRequestFile{
					Collection: block_data.CollectionBlock,
					RecordId:   configData.InternalBlockId,
					FileName:   file.Name,
				}
			}

			notionExporter := notion.NewNotionExporter(j.app)
			err := notionExporter.CreateVoiceNoteExporter(notion.CreateVoiceNoteRequest{
				Integration:      integration,
				DestinationId:    configData.DestinationId,
				BlockId:          configData.InternalBlockId,
				ExternalRecordId: externalRecordId,
				Files:            files,
			})
			if err != nil {
				return nil, err
			}
			return data.NewSummaryCompleteEmpty(), nil
		default:
			slog.Error("Unknown integration type", "type", reflect.TypeOf(genericIntegration))
			return nil, fmt.Errorf("Unknown integration type: %s", reflect.TypeOf(genericIntegration))
		}
	default:
		slog.Error("unknown export job type", "type", genericExportJob.Type())
		return nil, fmt.Errorf("unknown export job type: %s", genericExportJob.Type())
	}
}

func (j *exportJobRunnerConfig) integrationForDestination(
	destinationId string,
	userId string,
) (integ_data.Integration, error) {
	// Get destination
	destinationFetcher := block_data.NewDestinationFetcher(j.app)
	destination, err := destinationFetcher.FetchById(destinationId)
	if err != nil {
		slog.Error("Error fetching destination by id", "destinationId", destinationId, "err", err)
		return nil, err
	}
	if destination == nil {
		slog.Error("Destination not found", "destinationId", destinationId)
		return nil, fmt.Errorf("Destination not found")
	}

	// Get workspace for destination
	workspaceFetcher := block_data.NewWorkspaceFetcher(j.app)
	workspace, err := workspaceFetcher.FetchById(destination.Workspace())
	if err != nil {
		slog.Error(
			"Error fetching workspace by destination id",
			"destinationId",
			destinationId,
			"err",
			err,
		)
		return nil, err
	}
	if workspace == nil {
		slog.Error("Workspace not found", "workspaceId", destination.Workspace())
		return nil, fmt.Errorf("Workspace not found")
	}

	// Get integration for workspace
	integrationId := workspace.Integration()
	if integrationId == "" {
		slog.Info("No integration for workspace", "workspaceId", workspace.Id())
		return nil, nil
	}
	integrationFetcher := integ_data.NewIntegrationFetcher(j.app)
	integration, err := integrationFetcher.FetchById(integrationId, userId)
	if err != nil {
		slog.Error("Error fetching integration by id", "integrationId", integrationId, "err", err)
		return nil, err
	}
	if integration == nil {
		slog.Error("Integration not found by id", "integrationId", integrationId)
		return nil, fmt.Errorf("Integration not found")
	}
	return integration, nil
}

func (j *exportJobRunnerConfig) getExternalRecordId(destinationId string) (string, error) {
	integrationDestinationRepo := integ_data.NewIntegrationDestinationFetcher(j.app)
	integrationDestination, err := integrationDestinationRepo.FetchByDestinationId(destinationId)
	if err != nil {
		slog.Error(
			"Error fetching integration destination by destination id",
			"destinationId",
			destinationId,
			"err",
			err,
		)
		return "", err
	}
	if integrationDestination == nil {
		slog.Error("Integration destination not found", "destinationId", destinationId)
		return "", fmt.Errorf("Integration destination not found")
	}

	return integrationDestination.ExternalRecordId(), nil
}
