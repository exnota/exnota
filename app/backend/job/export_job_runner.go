package job

import (
	"fmt"
	"log/slog"
	"reflect"

	"exnota.com/backend/block"
	block_data "exnota.com/backend/block/data"
	integ_data "exnota.com/backend/integration/data"
	"exnota.com/backend/integration/usecase/notion"
	"exnota.com/backend/job/data"
	"github.com/mitchellh/mapstructure"
	"github.com/pocketbase/pocketbase/core"
)

type ExportJobRunner interface {
	RunnableBlockJob
}

type exportJobRunnerConfig struct {
	app              core.App
	workspaceFetcher block.WorkspaceFetcher
}

func NewExportJobRunner(app core.App, workspaceFetcher block.WorkspaceFetcher) ExportJobRunner {
	return &exportJobRunnerConfig{app, workspaceFetcher}
}

func (j *exportJobRunnerConfig) Run(genericJob data.BlockJob, app core.App) (data.Summary, error) {
	job, err := data.LoadExportBlockJob(genericJob.Record(), app)
	if err != nil {
		return nil, err
	}

	// Get integration info
	config, err := job.Config()
	if err != nil {
		return nil, err
	}
	destination := config.Data.Destination
	genericIntegration, err := j.integrationForDestination(destination, job.User())
	if err != nil {
		return nil, err
	}

	// Complete job if destination isn't integrated
	if genericIntegration == nil {
		slog.Info("No integration for destination", "destinationId", destination)
		return data.NewSummaryComplete(
			"No integration for destination " + destination,
		), nil
	}

	// Call appropriate integration type handler
	switch integration := genericIntegration.(type) {
	case integ_data.NotionIntegration:
		slog.Info("Running Notion export job", "job", job.ID())
		notionExporter := notion.NewNotionExporter(j.app)
		exportRequest := notion.NoteRequest{
			Integration: integration,
			Command:     notion.ExportCommand(config.Command),
			Id:          config.Data.Id,
			Title:       config.Data.Title,
			Type:        notion.ExportBlockType(config.Data.Type),
			Destination: config.Data.Destination,
			File:        config.Data.File,
		}
		if config.Data.Audio != nil {
			exportRequest.Audio = &notion.AudioField{
				Transcription: config.Data.Audio.Transcription,
			}
		}

		exportResult, err := notionExporter.Export(exportRequest)
		if err != nil {
			return nil, err
		}
		return j.exportResultToSummary(exportResult)
	default:
		slog.Error("Unknown integration type", "type", reflect.TypeOf(genericIntegration))
		return nil, fmt.Errorf("Unknown integration type: %s", reflect.TypeOf(genericIntegration))
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

	// #156: TODO: Handle block jobs when workspace archived
	// Get workspace for destination
	workspace, err := j.workspaceFetcher.FetchById(destination.Workspace())
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
	integration, err := integrationFetcher.FetchById(integ_data.FetchByIdRequest{
		IntegrationId: integrationId,
		UserId:        userId,
	})
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

func (j *exportJobRunnerConfig) exportResultToSummary(
	result *notion.ExportResult,
) (data.Summary, error) {
	if result == nil {
		slog.Warn("Export result is nil")
		return data.NewSummaryCompleteEmpty(), nil
	}

	resultData := map[string]interface{}{}
	err := mapstructure.Decode(result.ConfigUpdate, &resultData)
	if err != nil {
		return nil, err
	}
	return data.NewSummaryWithData(result.Message, resultData), nil
}
