package data

import (
	"reflect"
	"testing"
	"time"

	"exnota.com/backend/test"
	"github.com/go-playground/validator/v10"
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
		record.Set("summary", `{"message": "a summary"}`)
		record.Set("block", "the block id")
		record.Set("user", "the user id")
		record.Set("next_run_at", "2021-01-01T00:00:00Z")
		record.Set("error_count", 0)
		record.Set(
			"config",
			`{"command":"create_voice_note","data":{"internal_block_id":"the block id","destination_id":"the destination id","files":[{"path":"the path","name":"the name"}]}}`,
		)

		t.Run("An unknown type will error", func(t *testing.T) {
			unknownTypeRecord := models.NewRecord(collection)
			unknownTypeRecord.SetId("15-character-id")
			unknownTypeRecord.Set("type", "unknown")
			unknownTypeRecord.Set("status", "waiting")
			unknownTypeRecord.Set("summary", `{"message": "a summary"}`)
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
				t.Errorf(
					"NewExportBlockJob() form type = %v, want %v",
					job.Type(),
					BlockJobTypeExport,
				)
			}
		})

		t.Run("Status can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.Status() != BlockJobStatusWaiting {
				t.Errorf(
					"NewExportBlockJob() form status = %v, want %v",
					job.Status(),
					BlockJobStatusWaiting,
				)
			}
		})

		t.Run("Summary can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			summary, err := job.Summary()
			if err != nil {
				t.Fatal(err)
			}
			expectedSummary := map[string]interface{}{
				"message": "a summary",
			}
			if reflect.DeepEqual(summary, expectedSummary) {
				t.Errorf(
					"NewExportBlockJob() returned unexpected summary: got %v, want %v",
					summary,
					expectedSummary,
				)
			}
		})

		t.Run("Block can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.Block() != "the block id" {
				t.Errorf(
					"NewExportBlockJob() returned unexpected block: got %v, want %v",
					job.Block(),
					"the block id",
				)
			}
		})

		t.Run("User can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.User() != "the user id" {
				t.Errorf(
					"NewExportBlockJob() returned unexpected user: got %v, want %v",
					job.User(),
					"the user id",
				)
			}
		})

		t.Run("NextRunAt can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			expectedTime, _ := time.Parse(time.RFC3339, "2021-01-01T00:00:00Z")
			if !job.NextRunAt().Equal(expectedTime) {
				t.Errorf(
					"NewExportBlockJob() returned unexpected next run time: got %v, want %v",
					job.NextRunAt(),
					expectedTime,
				)
			}
		})

		t.Run("ErrorCount can be read", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if job.ErrorCount() != 0 {
				t.Errorf(
					"NewExportBlockJob() returned unexpected error count: got %v, want %v",
					job.ErrorCount(),
					0,
				)
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
		record.Set("summary", `{"message": "a summary"}`)
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
				t.Errorf(
					"NewBlockJob() returned unexpected type: got %T, want %T",
					job,
					TranscriptionBlockJob(nil),
				)
			}
		})

		t.Run("NewTranscriptionBlockJob factory errors if not an export type", func(t *testing.T) {
			exportRecord := models.NewRecord(collection)
			exportRecord.SetId("15-character-id")
			exportRecord.Set("type", "export")
			exportRecord.Set("status", "waiting")
			exportRecord.Set("summary", `{"message": "a summary"}`)
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
		record.Set("summary", `{"message": "a summary"}`)
		record.Set("block", "the block id")
		record.Set("user", "the user id")
		record.Set("next_run_at", "2021-01-01T00:00:00Z")
		record.Set("error_count", 0)
		record.Set(
			"config",
			`{"command":"create_voice_note","data":{"internal_block_id":"the block id","destination_id":"the destination id","files":[{"path":"the path","name":"the name"}]}}`,
		)

		t.Run("NewBlockJob factory returns an ExportBlockJob", func(t *testing.T) {
			job, err := NewBlockJob(record, app)
			if err != nil {
				t.Fatal(err)
			}
			if _, ok := job.(ExportBlockJob); !ok {
				t.Errorf(
					"NewBlockJob() returned unexpected type: got %T, want %T",
					job,
					ExportBlockJob(nil),
				)
			}
		})

		t.Run("NewExportBlockJob factory errors if not an export type", func(t *testing.T) {
			exportRecord := models.NewRecord(collection)
			exportRecord.SetId("15-character-id")
			exportRecord.Set("type", "transcription")
			exportRecord.Set("status", "waiting")
			exportRecord.Set("summary", `{"message": "a summary"}`)
			exportRecord.Set("block", "the block id")
			exportRecord.Set("user", "the user id")
			exportRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			exportRecord.Set("error_count", 0)
			exportRecord.Set("config", nil)

			_, err := LoadExportBlockJob(exportRecord, app)
			if err == nil {
				t.Errorf("NewExportBlockJob() did not return an error")
			}
		})

		t.Run("LoadExportBlockJob factory errors if config is nil", func(t *testing.T) {
			invalidConfigRecord := models.NewRecord(collection)
			invalidConfigRecord.SetId("15-character-id")
			invalidConfigRecord.Set("type", "export")
			invalidConfigRecord.Set("status", "waiting")
			invalidConfigRecord.Set("summary", `{"message": "a summary"}`)
			invalidConfigRecord.Set("block", "the block id")
			invalidConfigRecord.Set("user", "the user id")
			invalidConfigRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			invalidConfigRecord.Set("error_count", 0)
			invalidConfigRecord.Set("config", nil)

			_, err := LoadExportBlockJob(invalidConfigRecord, app)
			if err == nil {
				t.Errorf("LoadExportBlockJob() did not return an error")
			}
		})

		t.Run("LoadExportBlockJob factory errors if config is invalid JSON", func(t *testing.T) {
			invalidConfigRecord := models.NewRecord(collection)
			invalidConfigRecord.SetId("15-character-id")
			invalidConfigRecord.Set("type", "export")
			invalidConfigRecord.Set("status", "waiting")
			invalidConfigRecord.Set("summary", `{"message": "a summary"}`)
			invalidConfigRecord.Set("block", "the block id")
			invalidConfigRecord.Set("user", "the user id")
			invalidConfigRecord.Set("next_run_at", "2021-01-01T00:00:00Z")
			invalidConfigRecord.Set("error_count", 0)
			invalidConfigRecord.Set("config", `{"invalid json"}`)

			_, err := LoadExportBlockJob(invalidConfigRecord, app)
			if err == nil {
				t.Errorf("LoadExportBlockJob() did not return an error")
			}
		})

		t.Run("Config is validated", func(t *testing.T) {
			t.Run("Command must be valid", func(t *testing.T) {
				job, err := CreateExportJob(app)
				if err != nil {
					t.Fatal(err)
				}
				err = job.SetConfig(ExportJobConfig{
					Command: "invalid command",
					Data: ExportJobData{
						Id:          "the block id",
						Type:        BlockTypeVoiceNote,
						Destination: "the destination id",
					},
				})
				if err == nil {
					t.Errorf("SetConfig() did not return an invalid command error")
				} else {
					if validationErrors, ok := err.(validator.ValidationErrors); !ok {
						t.Errorf("SetConfig() returned an unexpected error: got %T, want %T", err, validator.ValidationErrors{})
					} else {
						hi := validationErrors[0]
						if hi.Tag() != "oneof" {
							t.Errorf("SetConfig() returned an unexpected error: got %v, want %v", hi.Tag(), "oneof")
						}
					}
				}
			})
			t.Run("Type must be valid", func(t *testing.T) {
				job, err := CreateExportJob(app)
				if err != nil {
					t.Fatal(err)
				}
				err = job.SetConfig(ExportJobConfig{
					Command: CommandCreateVoiceNote,
					Data: ExportJobData{
						Id:          "the block id",
						Type:        "invalid type",
						Destination: "the destination id",
					},
				})
				if err == nil {
					t.Errorf("SetConfig() did not return an invalid type error")
				} else {
					if validationErrors, ok := err.(validator.ValidationErrors); !ok {
						t.Errorf("SetConfig() returned an unexpected error: got %T, want %T", err, validator.ValidationErrors{})
					} else {
						hi := validationErrors[0]
						if hi.Tag() != "oneof" {
							t.Errorf("SetConfig() returned an unexpected error: got %v, want %v", hi.Tag(), "oneof")
						}
					}
				}
			})
		})
		t.Run("Export job data is invalid if required fields are missing", func(t *testing.T) {
			t.Run("Errors if Id is missing", func(t *testing.T) {
				job, err := CreateExportJob(app)
				if err != nil {
					t.Fatal(err)
				}
				err = job.SetConfig(ExportJobConfig{
					Command: CommandCreateVoiceNote,
					Data: ExportJobData{
						Type:        BlockTypeVoiceNote,
						Destination: "the destination id",
					},
				})
				if err == nil {
					t.Errorf("SetConfig() did not return an id required error")
				} else {
					if validationErrors, ok := err.(validator.ValidationErrors); !ok {
						t.Errorf("SetConfig() returned an unexpected error: got %T, want %T", err, validator.ValidationErrors{})
					} else {
						hi := validationErrors[0]
						if hi.Tag() != "required" {
							t.Errorf("SetConfig() returned an unexpected error: got %v, want %v", hi.Tag(), "required")
						}
					}
				}
			})
			t.Run("Errors if type is missing", func(t *testing.T) {
				job, err := CreateExportJob(app)
				if err != nil {
					t.Fatal(err)
				}
				err = job.SetConfig(ExportJobConfig{
					Command: CommandCreateVoiceNote,
					Data: ExportJobData{
						Id:          "the block id",
						Destination: "the destination id",
					},
				})
				if err == nil {
					t.Errorf("SetConfig() did not return a type required error")
				} else {
					if validationErrors, ok := err.(validator.ValidationErrors); !ok {
						t.Errorf("SetConfig() returned an unexpected error: got %T, want %T", err, validator.ValidationErrors{})
					} else {
						hi := validationErrors[0]
						if hi.Tag() != "required" {
							t.Errorf("SetConfig() returned an unexpected error: got %v, want %v", hi.Tag(), "required")
						}
					}
				}
			})
			t.Run("Errors if destination is missing", func(t *testing.T) {
				job, err := CreateExportJob(app)
				if err != nil {
					t.Fatal(err)
				}
				err = job.SetConfig(ExportJobConfig{
					Command: CommandCreateVoiceNote,
					Data: ExportJobData{
						Id:   "the block id",
						Type: BlockTypeVoiceNote,
					},
				})
				if err == nil {
					t.Errorf("SetConfig() did not return a destination required error")
				} else {
					if validationErrors, ok := err.(validator.ValidationErrors); !ok {
						t.Errorf("SetConfig() returned an unexpected error: got %T, want %T", err, validator.ValidationErrors{})
					} else {
						hi := validationErrors[0]
						if hi.Tag() != "required" {
							t.Errorf("SetConfig() returned an unexpected error: got %v, want %v", hi.Tag(), "required")
						}
					}
				}
			})
		})

	})

}
