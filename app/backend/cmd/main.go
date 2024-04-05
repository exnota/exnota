package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"strings"

	block_api "exnota.com/backend/block/api"
	block_data "exnota.com/backend/block/data"
	integ_api "exnota.com/backend/integration/api"
	integ_data "exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service"
	"exnota.com/backend/job"
	job_data "exnota.com/backend/job/data"
	_ "exnota.com/backend/migrations"
	user_api_hooks "exnota.com/backend/user/api"
	"github.com/caarlos0/env"
	validation "github.com/go-ozzo/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/forms/validators"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/types"
)

func main() {
	cfg := Config{}
	err := env.Parse(&cfg)
	if err != nil {
		panic(err)
	}

	app := pocketbase.New()

	// Custom flags
	cmd := app.RootCmd
	var skipWorkersCmd bool
	cmd.PersistentFlags().BoolVar(
		&skipWorkersCmd,
		"skip-workers",
		false,
		"Skips the queuing of created jobs to prevent background workers from running",
	)

	// Migrations
	autoMigrate := isAutoMigrate()
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		// enable auto creation of migration files when making collection changes in the Admin UI
		// (the isGoRun check is to enable it only during development)
		Automigrate: autoMigrate,
	})

	initJobWorker(app)
	bindRequestAndRecordHooks(app, cfg, &skipWorkersCmd)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

const (
	COLLECTION_USER = "user"

	COLLECTION_BLOCK  = "block"
	BLOCK_FIELD_TYPE  = "type"
	BLOCK_FIELD_USER  = "user"
	BLOCK_FIELD_TITLE = "title"
	BLOCK_FIELD_FILE  = "file"

	COLLECTION_BLOCK_JOB         = "block_job"
	BLOCK_JOB_FIELD_TYPE         = "type"
	BLOCK_JOB_TYPE_TRANSCRIPTION = "transcription"
	BLOCK_JOB_TYPE_EXPORT        = "export"
	BLOCK_JOB_FIELD_STATUS       = "status"
	BLOCK_JOB_STATUS_WAITING     = "waiting"
	BLOCK_JOB_STATUS_RUNNING     = "running"
	BLOCK_JOB_STATUS_ERROR       = "error"
	BLOCK_JOB_STATUS_COMPLETE    = "complete"
	BLOCK_JOB_FIELD_SUMMARY      = "summary"
	BLOCK_JOB_FIELD_BLOCK        = "block"
	BLOCK_JOB_FIELD_USER         = "user"
)

func isAutoMigrate() bool {
	isGoRun := strings.HasPrefix(os.Args[0], os.TempDir())
	isVsCodeDebug := strings.HasPrefix(os.Args[0], "/workspaces/exnota/app/backend")
	autoMigrate := isGoRun || isVsCodeDebug
	if autoMigrate {
		fmt.Println("Automigrations on")
	} else {
		fmt.Println("Automigrations off")
	}
	return autoMigrate
}

func initJobWorker(app core.App) {
	jobQueue := job.NewBlockJobQueue(app)
	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		return jobQueue.Start()
	})
}

func bindRequestAndRecordHooks(app core.App, cfg Config, skipWorkers *bool) {
	// serves static files from the provided public dir (if exists)
	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET("/*", apis.StaticDirectoryHandler(os.DirFS("./pb_public"), false))
		return nil
	})

	// initJobWorker(app)
	// bindJobCreatorHooks(app)

	// Global rules
	user_api_hooks.NewUserRequestHooks(app).Apply()
	setGlobalDeleteRules(app)

	// Data rules
	integ_data.NewIntegrationDataRules(app).ApplyHooks()
	integ_data.NewIntegrationNotionObjectHooks(app).ApplyHooks()
	integ_data.NewIntegrationDestinationDataRules(app).ApplyHooks()
	block_data.NewWorkspaceDataRules(app).ApplyHooks()
	integrationDestinationSync := service.NewIntegrationDestinationSync(app)
	block_data.NewDestinationDataRules(app).ApplyHooks()

	// API rules
	integ_api.NewIntegrationRequestHooks(app, integ_api.NotionCredentials{
		ClientId: cfg.NotionOAuthClientID,
		Secret:   cfg.NotionOAuthClientSecret,
	}).Apply()
	integ_api.NewIntegrationNotionObjectApiRules(app).ApplyHooks()
	integ_api.NewIntegrationDestinationApiRules(app).ApplyHooks()
	block_api.NewDestinationApiRules(app, integrationDestinationSync.Sync).ApplyHooks()

	// Custom endpoints
	integ_api.NewIntegrationEndpointHooks(app, integ_api.IntegrationEndpointConfig{
		BasePath:               cfg.BasePath,
		NotionClientID:         cfg.NotionOAuthClientID,
		NotionRedirectBasePath: cfg.NotionRedirectBasePath,
	}).Apply()

	// Old rules, need extracting/refactoring
	setBlockInvariants(app)
	setBlockJobInvariants(app)

	// Job creation
	setBlockTranscriptionHooks(app, skipWorkers)
	setBlockExportHooks(app)
}

func setGlobalDeleteRules(app core.App) {
	// deleting not allowed on any collection
	app.OnModelBeforeDelete().Add(func(e *core.ModelEvent) error {
		// Create `archived` fields instead.
		return errors.New("Cannot delete. Archive instead.")
	})
}

func setBlockInvariants(app core.App) {
	// type cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newType := e.Record.GetString(BLOCK_FIELD_TYPE)

		if newType != existingRecord.GetString(BLOCK_FIELD_TYPE) {
			return apis.NewBadRequestError("Cannot change block type", nil)
		}

		return nil
	})

	// user cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newUserId := e.Record.GetString(BLOCK_FIELD_USER)

		if newUserId != existingRecord.GetString(BLOCK_FIELD_USER) {
			return apis.NewBadRequestError("Cannot change block user", nil)
		}

		return nil
	})

	// file creation
	app.OnRecordBeforeCreateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordCreateEvent) error {
		newType := e.Record.GetString(BLOCK_FIELD_TYPE)

		// audio block must have a file
		if newType == "audio" {
			files := e.UploadedFiles[BLOCK_FIELD_FILE]
			if len(files) != 1 {
				return apis.NewBadRequestError("Audio block must have exactly 1 file", nil)
			}

			// Content types supported by Pocketbase: https://github.com/gabriel-vasile/mimetype/blob/master/supported_mimes.md
			// The mime type *may* also be in the attributes returned by filesystem.Attributes(): https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/tools/filesystem/filesystem.go#L104
			if err := validators.UploadedFileMimeType([]string{"audio/wav", "audio/mpeg"})(files[0]); err != nil {
				// Verify it's a mime type error, because if we simply return
				// the err object the error message will be a generic
				// "Something went wrong while processing your request."
				errObj := err.(validation.ErrorObject)
				if errObj.Code() == "validation_invalid_mime_type" {
					return apis.NewBadRequestError("Audio block must have a .wav or .mp3 file.", nil)
				}
				return err
			}
		} else {
			files := e.UploadedFiles[BLOCK_FIELD_FILE]
			if len(files) != 0 {
				return apis.NewBadRequestError("Non-audio block cannot have a file", nil)
			}
		}

		return nil
	})

	// file cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newFile := e.Record.Get(BLOCK_FIELD_FILE)

		if newFile != existingRecord.Get(BLOCK_FIELD_FILE) {
			return apis.NewBadRequestError("Cannot change block file", nil)
		}

		return nil
	})

}

func setBlockJobInvariants(app core.App) {
	// type cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newType := e.Record.GetString(BLOCK_JOB_FIELD_TYPE)

		if newType != existingRecord.GetString(BLOCK_JOB_FIELD_TYPE) {
			return apis.NewBadRequestError("Cannot change block job type", nil)
		}

		return nil
	})

	// user cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newUserId := e.Record.GetString(BLOCK_JOB_FIELD_USER)

		if newUserId != existingRecord.GetString(BLOCK_JOB_FIELD_USER) {
			return apis.NewBadRequestError("Cannot change block job user", nil)
		}

		return nil
	})

	// block cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newBlockId := e.Record.GetString(BLOCK_JOB_FIELD_BLOCK)

		if newBlockId != existingRecord.GetString(BLOCK_JOB_FIELD_BLOCK) {
			return apis.NewBadRequestError("Cannot change block job block", nil)
		}

		return nil
	})

	// user must match block's user
	app.OnRecordBeforeCreateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordCreateEvent) error {
		blockId := e.Record.GetString(BLOCK_JOB_FIELD_BLOCK)
		block, err := app.Dao().FindRecordById(COLLECTION_BLOCK, blockId, nil)
		if err != nil {
			return err
		}

		blockUserId := block.GetString(BLOCK_FIELD_USER)
		jobUserId := e.Record.GetString(BLOCK_JOB_FIELD_USER)

		if blockUserId != jobUserId {
			return apis.NewBadRequestError("Block job user must match block user", nil)
		}

		return nil
	})
}

func setBlockTranscriptionHooks(app core.App, skipWorkers *bool) {
	// On audio block creation, create a transcription job
	app.OnModelAfterCreate(COLLECTION_BLOCK).Add(func(e *core.ModelEvent) error {
		block := e.Model.(*models.Record)
		if block.GetString(BLOCK_FIELD_TYPE) == "audio" {
			collection, err := app.Dao().FindCollectionByNameOrId(COLLECTION_BLOCK_JOB)
			if err != nil {
				return err
			}

			job := models.NewRecord(collection)

			form := forms.NewRecordUpsert(app, job)

			err = form.LoadData(map[string]any{
				BLOCK_JOB_FIELD_TYPE:            BLOCK_JOB_TYPE_TRANSCRIPTION,
				BLOCK_JOB_FIELD_STATUS:          BLOCK_JOB_STATUS_WAITING,
				BLOCK_JOB_FIELD_BLOCK:           block.Id,
				BLOCK_JOB_FIELD_USER:            block.GetString(BLOCK_FIELD_USER),
				job_data.BlockJobFieldNextRunAt: types.NowDateTime(),
			})
			if err != nil {
				return err
			}

			// validate and submit (internally it calls app.Dao().SaveRecord(record) in a transaction)
			if err := form.Submit(); err != nil {
				return err
			}
		}
		return nil
	})
}

func setBlockExportHooks(app core.App) {
	// On transcription job completion, create an export job
	app.OnModelAfterUpdate(COLLECTION_BLOCK_JOB).Add(func(e *core.ModelEvent) error {
		// Transcription jobs only
		updatedJob := job_data.NewBlockJob(e.Model.(*models.Record), app)
		if updatedJob.Type() != job_data.BlockJobTypeTranscription {
			return nil
		}

		// Job complete events only
		if updatedJob.Status() != job_data.BlockJobStatusComplete {
			return nil
		}
		prevUpdatedJob := job_data.NewBlockJob(updatedJob.Record().OriginalCopy(), app)
		if prevUpdatedJob.Status() == job_data.BlockJobStatusComplete {
			return nil
		}

		collection, err := app.Dao().FindCollectionByNameOrId(COLLECTION_BLOCK_JOB)
		if err != nil {
			return err
		}

		form, err := job_data.NewExportBlockJobForm(job_data.NewExportBlockJobFormConfig{
			Collection: collection,
			App:        app,
			BlockId:    updatedJob.Block(),
			UserId:     updatedJob.User(),
		})
		if err != nil {
			return err
		}

		// validate and submit (internally it calls app.Dao().SaveRecord(record) in a transaction)
		if err := form.Submit(); err != nil {
			return err
		}
		return nil
	})
}
