package data

import (
	"testing"
	"time"

	"exnota.com/backend/test"
	"github.com/pocketbase/pocketbase/models"
)

func TestNewExportBlockJob(t *testing.T) {
	app := test.TestApp()
	defer app.Cleanup()

	t.Run("BlockJob interface", func(t *testing.T) {
		collection, err := app.Dao().FindCollectionByNameOrId("block_job")
		if err != nil {
			t.Fatal(err)
		}

		record := models.NewRecord(collection)
		record.SetId("15-character-id")
		record.Set("type", "export")
		record.Set("status", "waiting")
		record.Set("summary", "the summary")
		record.Set("block", "the block id")
		record.Set("user", "the user id")
		record.Set("next_run_at", "2021-01-01T00:00:00Z")
		record.Set("error_count", 0)
		record.Set("config", `{"command":"create_voice_note","data":{"internal_block_id":"the block id","destination_id":"the destination id","files":[{"path":"the path","name":"the name"}]}}`)

		t.Run("An unknown type will error", func(t *testing.T) {
			unknownTypeRecord := models.NewRecord(collection)
			unknownTypeRecord.SetId("15-character-id")
			unknownTypeRecord.Set("type", "unknown")
			unknownTypeRecord.Set("status", "waiting")
			unknownTypeRecord.Set("summary", "the summary")
			unknownTypeRecord.Set("block", "the block id")
			unknownTypeRecord.Set("user", "the user id")
			unknownTypeRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			unknownTypeRecord.Set("error_count", 0)
			unknownTypeRecord.Set("config", nil)

			_, err := NewBlockJob(unknownTypeRecord, app)
			if err == nil {
				t.Errorf("NewExportBlockJob() did not return an error")
			}
		})

		t.Run("Id can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.ID() != "15-character-id" {
				t.Errorf("NewExportBlockJob() form id = %v, want %v", job.ID(), "15-character-id")
			}
		})

		t.Run("Type can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.Type() != BlockJobTypeExport {
				t.Errorf("NewExportBlockJob() form type = %v, want %v", job.Type(), BlockJobTypeExport)
			}
		})

		t.Run("Status can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.Status() != BlockJobStatusWaiting {
				t.Errorf("NewExportBlockJob() form status = %v, want %v", job.Status(), BlockJobStatusWaiting)
			}
		})

		t.Run("Summary can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.Summary() != "\"the summary\"" {
				t.Errorf("NewExportBlockJob() returned unexpected summary: got %v, want %v", job.Summary(), "the summary")
			}
		})

		t.Run("Block can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.Block() != "the block id" {
				t.Errorf("NewExportBlockJob() returned unexpected block: got %v, want %v", job.Block(), "the block id")
			}
		})

		t.Run("User can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.User() != "the user id" {
				t.Errorf("NewExportBlockJob() returned unexpected user: got %v, want %v", job.User(), "the user id")
			}
		})

		t.Run("NextRunAt can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			expectedTime, _ := time.Parse(time.RFC3339, "2021-01-01T00:00:00Z")
			if !job.NextRunAt().Equal(expectedTime) {
				t.Errorf("NewExportBlockJob() returned unexpected next run time: got %v, want %v", job.NextRunAt(), expectedTime)
			}
		})

		t.Run("ErrorCount can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.ErrorCount() != 0 {
				t.Errorf("NewExportBlockJob() returned unexpected error count: got %v, want %v", job.ErrorCount(), 0)
			}
		})
	})

	t.Run("TranscriptionBlockJob interface", func(t *testing.T) {
		collection, err := app.Dao().FindCollectionByNameOrId("block_job")
		if err != nil {
			t.Fatal(err)
		}

		record := models.NewRecord(collection)
		record.SetId("15-character-id")
		record.Set("type", "transcription")
		record.Set("status", "waiting")
		record.Set("summary", "the summary")
		record.Set("block", "the block id")
		record.Set("user", "the user id")
		record.Set("next_run_at", "2021-01-01T00:00:00Z")
		record.Set("error_count", 0)
		record.Set("config", nil)

		t.Run("NewBlockJob factory returns a TranscriptionBlockJob", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if _, ok := job.(TranscriptionBlockJob); !ok {
				t.Errorf("NewBlockJob() returned unexpected type: got %T, want %T", job, TranscriptionBlockJob(nil))
			}
		})

		t.Run("NewTranscriptionBlockJob factory errors if not an export type", func(t *testing.T) {
			exportRecord := models.NewRecord(collection)
			exportRecord.SetId("15-character-id")
			exportRecord.Set("type", "export")
			exportRecord.Set("status", "waiting")
			exportRecord.Set("summary", "the summary")
			exportRecord.Set("block", "the block id")
			exportRecord.Set("user", "the user id")
			exportRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			exportRecord.Set("error_count", 0)
			exportRecord.Set("config", nil)

			_, err := NewTranscriptionBlockJob(exportRecord, app)
			if err == nil {
				t.Errorf("NewTranscriptionBlockJob() did not return an error")
			}
		})
	})

	t.Run("ExportBlockJob interface", func(t *testing.T) {
		collection, err := app.Dao().FindCollectionByNameOrId("block_job")
		if err != nil {
			t.Fatal(err)
		}

		record := models.NewRecord(collection)
		record.SetId("15-character-id")
		record.Set("type", "export")
		record.Set("status", "waiting")
		record.Set("summary", "the summary")
		record.Set("block", "the block id")
		record.Set("user", "the user id")
		record.Set("next_run_at", "2021-01-01T00:00:00Z")
		record.Set("error_count", 0)
		record.Set("config", `{"command":"create_voice_note","data":{"internal_block_id":"the block id","destination_id":"the destination id","files":[{"path":"the path","name":"the name"}]}}`)

		t.Run("NewBlockJob factory returns an ExportBlockJob", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if _, ok := job.(ExportBlockJob); !ok {
				t.Errorf("NewBlockJob() returned unexpected type: got %T, want %T", job, ExportBlockJob(nil))
			}
		})

		t.Run("NewExportBlockJob factory errors if not an export type", func(t *testing.T) {
			exportRecord := models.NewRecord(collection)
			exportRecord.SetId("15-character-id")
			exportRecord.Set("type", "transcription")
			exportRecord.Set("status", "waiting")
			exportRecord.Set("summary", "the summary")
			exportRecord.Set("block", "the block id")
			exportRecord.Set("user", "the user id")
			exportRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			exportRecord.Set("error_count", 0)
			exportRecord.Set("config", nil)

			_, err := NewExportBlockJob(exportRecord, app)
			if err == nil {
				t.Errorf("NewExportBlockJob() did not return an error")
			}
		})

		t.Run("NewExportBlockJob factory errors if config is nil", func(t *testing.T) {
			invalidConfigRecord := models.NewRecord(collection)
			invalidConfigRecord.SetId("15-character-id")
			invalidConfigRecord.Set("type", "export")
			invalidConfigRecord.Set("status", "waiting")
			invalidConfigRecord.Set("summary", "the summary")
			invalidConfigRecord.Set("block", "the block id")
			invalidConfigRecord.Set("user", "the user id")
			invalidConfigRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			invalidConfigRecord.Set("error_count", 0)
			invalidConfigRecord.Set("config", nil)

			_, err := NewExportBlockJob(invalidConfigRecord, app)
			if err == nil {
				t.Errorf("NewExportBlockJob() did not return an error")
			}
		})

		t.Run("NewExportBlockJob factory errors if config is invalid JSON", func(t *testing.T) {
			invalidConfigRecord := models.NewRecord(collection)
			invalidConfigRecord.SetId("15-character-id")
			invalidConfigRecord.Set("type", "export")
			invalidConfigRecord.Set("status", "waiting")
			invalidConfigRecord.Set("summary", "the summary")
			invalidConfigRecord.Set("block", "the block id")
			invalidConfigRecord.Set("user", "the user id")
			invalidConfigRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			invalidConfigRecord.Set("error_count", 0)
			invalidConfigRecord.Set("config", `{"invalid json"}`)

			_, err := NewExportBlockJob(invalidConfigRecord, app)
			if err == nil {
				t.Errorf("NewExportBlockJob() did not return an error")
			}
		})

		t.Run("NewExportBlockJob factory errors if config command is invalid", func(t *testing.T) {
			invalidConfigRecord := models.NewRecord(collection)
			invalidConfigRecord.SetId("15-character-id")
			invalidConfigRecord.Set("type", "export")
			invalidConfigRecord.Set("status", "waiting")
			invalidConfigRecord.Set("summary", "the summary")
			invalidConfigRecord.Set("block", "the block id")
			invalidConfigRecord.Set("user", "the user id")
			invalidConfigRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			invalidConfigRecord.Set("error_count", 0)
			invalidConfigRecord.Set("config", `{"command":"invalid command"}`)

			_, err := NewExportBlockJob(invalidConfigRecord, app)
			if err == nil {
				t.Errorf("NewExportBlockJob() did not return an error")
			}
		})

	})
	t.Run("CreateVoiceNoteJob interface", func(t *testing.T) {
		collection, err := app.Dao().FindCollectionByNameOrId("block_job")
		if err != nil {
			t.Fatal(err)
		}

		record := models.NewRecord(collection)
		record.SetId("15-character-id")
		record.Set("type", "export")
		record.Set("status", "waiting")
		record.Set("summary", "the summary")
		record.Set("block", "the block id")
		record.Set("user", "the user id")
		record.Set("next_run_at", "2021-01-01T00:00:00Z")
		record.Set("error_count", 0)
		record.Set("config", `{"command":"create_voice_note","data":{"internal_block_id":"the block id","destination_id":"the destination id","files":[{"path":"the path","name":"the name"}]}}`)

		t.Run("NewBlockJob factory returns a CreateVoiceNoteJob", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if _, ok := job.(CreateVoiceNoteJob); !ok {
				t.Errorf("NewBlockJob() returned unexpected type: got %T, want %T", job, CreateVoiceNoteJob(nil))
			}
		})

		t.Run("NewExportBlockJob factory returns a CreateVoiceNoteJob", func(t *testing.T) {
			job, err := NewExportBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if _, ok := job.(CreateVoiceNoteJob); !ok {
				t.Errorf("NewExportBlockJob() returned unexpected type: got %T, want %T", job, CreateVoiceNoteJob(nil))
			}
		})

		t.Run("NewCreateVoiceNoteJob factory errors if not an export type", func(t *testing.T) {
			exportRecord := models.NewRecord(collection)
			exportRecord.SetId("15-character-id")
			exportRecord.Set("type", "transcription")
			exportRecord.Set("status", "waiting")
			exportRecord.Set("summary", "the summary")
			exportRecord.Set("block", "the block id")
			exportRecord.Set("user", "the user id")
			exportRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			exportRecord.Set("error_count", 0)
			exportRecord.Set("config", nil)

			_, err := NewCreateVoiceNoteJob(exportRecord, app)
			if err == nil {
				t.Errorf("NewCreateVoiceNoteJob() did not return an error")
			}
		})

		t.Run("NewCreateVoiceNoteJob factory errors if not a create voice note command", func(t *testing.T) {
			invalidConfigRecord := models.NewRecord(collection)
			invalidConfigRecord.SetId("15-character-id")
			invalidConfigRecord.Set("type", "export")
			invalidConfigRecord.Set("status", "waiting")
			invalidConfigRecord.Set("summary", "the summary")
			invalidConfigRecord.Set("block", "the block id")
			invalidConfigRecord.Set("user", "the user id")
			invalidConfigRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			invalidConfigRecord.Set("error_count", 0)
			invalidConfigRecord.Set("config", `{"command":"invalid command"}`)

			_, err := NewCreateVoiceNoteJob(invalidConfigRecord, app)
			if err == nil {
				t.Errorf("NewCreateVoiceNoteJob() did not return an error")
			}
		})

		t.Run("ConfigData returns the config data", func(t *testing.T) {
			job, err := NewCreateVoiceNoteJob(record, app)
			if err != nil {
				t.Fatal(err)
			}

			configData, err := job.ConfigData()
			if err != nil {
				t.Fatal(err)
			}

			if configData.InternalBlockId != "the block id" {
				t.Errorf("ConfigData() returned unexpected internal block id: got %v, want %v", configData.InternalBlockId, "the block id")
			}
			if configData.DestinationId != "the destination id" {
				t.Errorf("ConfigData() returned unexpected destination id: got %v, want %v", configData.DestinationId, "the destination id")
			}
			if configData.Files[0].Path != "the path" {
				t.Errorf("ConfigData() returned unexpected file path: got %v, want %v", configData.Files[0].Path, "the path")
			}
			if configData.Files[0].Name != "the name" {
				t.Errorf("ConfigData() returned unexpected file name: got %v, want %v", configData.Files[0].Name, "the name")
			}
		})

		t.Run("ConfigData errors if data is invalid JSON", func(t *testing.T) {
			invalidConfigRecord := models.NewRecord(collection)
			invalidConfigRecord.SetId("15-character-id")
			invalidConfigRecord.Set("type", "export")
			invalidConfigRecord.Set("status", "waiting")
			invalidConfigRecord.Set("summary", "the summary")
			invalidConfigRecord.Set("block", "the block id")
			invalidConfigRecord.Set("user", "the user id")
			invalidConfigRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			invalidConfigRecord.Set("error_count", 0)
			invalidConfigRecord.Set("config", `{"command":"create_voice_note","data":{"key":"value"}}`)
			job, err := NewCreateVoiceNoteJob(invalidConfigRecord, app)
			if err != nil {
				t.Fatal(err)
			}

			_, err = job.ConfigData()
			if err == nil {
				t.Errorf("ConfigData() did not return an error")
			}
		})
	})

}
