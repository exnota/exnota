package event

import (
	"exnota.com/backend/block"
	"exnota.com/backend/block/data"
	integ "exnota.com/backend/integration"
	block_job_data "exnota.com/backend/job/data"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

type BlockStatusListener interface {
	ApplyHooks()
}

type blockStatusListener struct {
	app core.App
}

func NewBlockStatusListener(app core.App) BlockStatusListener {
	return &blockStatusListener{
		app: app,
	}
}

func (l *blockStatusListener) ApplyHooks() {
	l.applyHooksToUpdateExternalUrl()
	l.applyHooksToUpdateExternalExportStatus()
}

// TODO: Decouple from integration domain
func (l *blockStatusListener) applyHooksToUpdateExternalUrl() {
	// On Notion mapping create, update external URL if already set
	l.app.OnModelAfterCreate(
		integ.CollectionIntegrationBlockNotionMapping).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			mapping, err := integ.LoadIntegrationBlockNotionMapping(record, l.app)
			if err != nil {
				return err
			}

			if mapping.ExternalUrl() == "" {
				return nil
			}

			writer := data.NewBlockWriter(l.app)
			err = writer.SetExternalUrl(mapping.InternalBlock(), mapping.ExternalUrl())
			if err != nil {
				return err
			}

			return nil
		},
	)

	// On Notion mapping update, update external URL if it has changed
	l.app.OnModelAfterUpdate(
		integ.CollectionIntegrationBlockNotionMapping).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			newMapping, err := integ.LoadIntegrationBlockNotionMapping(record, l.app)
			if err != nil {
				return err
			}

			prevMapping, err := integ.LoadIntegrationBlockNotionMapping(
				record.OriginalCopy(),
				l.app,
			)
			if err != nil {
				return err
			}

			if prevMapping.ExternalUrl() != newMapping.ExternalUrl() {
				writer := data.NewBlockWriter(l.app)
				err = writer.SetExternalUrl(newMapping.InternalBlock(), newMapping.ExternalUrl())
				if err != nil {
					return err
				}
			}

			return nil
		},
	)
}

// TODO: Either decouple from block domain or move jobs into block domain
func (l *blockStatusListener) applyHooksToUpdateExternalExportStatus() {
	l.app.OnModelAfterCreate(
		block_job_data.CollectionBlockJob).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			job, err := block_job_data.LoadBlockJob(record, l.app)
			if err != nil {
				return err
			}

			return l.updateExternalStatus(job)
		},
	)

	l.app.OnModelAfterUpdate(
		block_job_data.CollectionBlockJob).Add(
		func(e *core.ModelEvent) error {
			record := e.Model.(*models.Record)
			job, err := block_job_data.LoadBlockJob(record, l.app)
			if err != nil {
				return err
			}

			prevJob, err := block_job_data.LoadBlockJob(record.OriginalCopy(), l.app)
			if err != nil {
				return err
			}
			if job.Status() == prevJob.Status() {
				return nil
			}

			return l.updateExternalStatus(job)

		},
	)
}

func (l *blockStatusListener) updateExternalStatus(
	job block_job_data.BlockJob,
) error {
	// Get jobs
	fetcher := block_job_data.NewBlockJobFetcher(l.app)
	jobs, err := fetcher.ListJobs(block_job_data.ListJobsRequest{
		BlockId: job.Block(),
		UserId:  job.User(),
	})
	if err != nil {
		return err
	}

	// Get statuses of jobs.
	var hasError bool
	var nonCompleteCount int
	for _, j := range jobs {
		if j.Status() == block_job_data.BlockJobStatusError {
			hasError = true
			break
		}
		if j.Status() != block_job_data.BlockJobStatusComplete {
			nonCompleteCount++
		}
	}

	// Consolidate job status to block export status
	//
	// - If at least one error -> error
	// - Else if at least one non-complete -> in-progress
	// - Else -> complete
	var exportStatus block.ExportStatus
	if hasError {
		exportStatus = block.ExportStatusError
	} else if nonCompleteCount > 0 {
		exportStatus = block.ExportStatusInProgress
	} else {
		exportStatus = block.ExportStatusComplete
	}

	// Save
	writer := data.NewBlockWriter(l.app)
	err = writer.SetExternalExportStatus(job.Block(), exportStatus)
	return err
}
