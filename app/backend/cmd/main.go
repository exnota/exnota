package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"exnota.com/backend/api"
	integration_api_hooks "exnota.com/backend/integration/api"
	"exnota.com/backend/job"
	_ "exnota.com/backend/migrations"
	"exnota.com/backend/record"
	user_api_hooks "exnota.com/backend/user/api"
	validation "github.com/go-ozzo/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/forms/validators"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
)

func main() {
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

	bindAppHooks(app, &skipWorkersCmd)

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

func bindAppHooks(app core.App, skipWorkers *bool) {
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

	// Domain rules
	integration_api_hooks.NewRequestHooks(app).Apply()
	setBlockInvariants(app)
	setBlockJobInvariants(app)

	// Processing
	setBlockTranscriptionHooks(app, skipWorkers)
	setBlockExportHooks(app, skipWorkers)
}

func setGlobalDeleteRules(app core.App) {
	// deleting not allowed on any collection
	app.OnModelBeforeDelete().Add(func(e *core.ModelEvent) error {
		// Create `archived` fields instead.
		return api.NewMethodNotAllowedError("Cannot delete. Archive instead.", nil)
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
				BLOCK_JOB_FIELD_TYPE:   BLOCK_JOB_TYPE_TRANSCRIPTION,
				BLOCK_JOB_FIELD_STATUS: BLOCK_JOB_STATUS_WAITING,
				BLOCK_JOB_FIELD_BLOCK:  block.Id,
				BLOCK_JOB_FIELD_USER:   block.GetString(BLOCK_FIELD_USER),
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

	jobs := make(chan TranscriptionWorkerJob)
	results := make(chan string)

	for w := 1; w <= 2; w++ {
		go transcriptionWorker(w, jobs, results, app)
	}

	// On transcription job creation, queue it for processing
	app.OnModelAfterCreate(COLLECTION_BLOCK_JOB).Add(func(e *core.ModelEvent) error {
		// Flags are resolved (it seems) on app.Start(), so this check has been
		// added inside the hook, rather than preventing the hook from being
		// created, as that happens before app.Start() is called.
		if *skipWorkers {
			return nil
		}

		record := e.Model.(*models.Record)
		if record.GetString(BLOCK_JOB_FIELD_TYPE) != BLOCK_JOB_TYPE_TRANSCRIPTION {
			return nil
		}
		if record.GetString(BLOCK_JOB_FIELD_STATUS) != BLOCK_JOB_STATUS_WAITING {
			return fmt.Errorf("Job %s created with a status other than waiting", record.Id)
		}

		jobs <- TranscriptionWorkerJob{
			BlockJobId: record.Id,
			BlockId:    record.GetString(BLOCK_JOB_FIELD_BLOCK),
		}
		return nil
	})
}

type TranscriptionWorkerJob struct {
	BlockJobId string
	BlockId    string
}

func transcriptionWorker(id int, jobs <-chan TranscriptionWorkerJob, results chan<- string, app core.App) {
	for j := range jobs {
		fmt.Println("transcription worker", id, "started block job", j.BlockJobId, "for block", j.BlockId)

		transJob := job.NewTranscriptionJobRunner(j.BlockJobId, j.BlockId, app)
		err := transJob.Run()
		if err != nil {
			fmt.Println("transcription worker", id, "errored running job", j.BlockJobId, "for block", j.BlockId, "with error", err)
			continue
		}

		// results <- "done"
		fmt.Println("transcription worker", id, "finished job", j.BlockJobId, "for block", j.BlockId)
	}
}

func setBlockExportHooks(app core.App, skipWorkers *bool) {
	// On transcription job completion, create an export job
	app.OnModelAfterUpdate(COLLECTION_BLOCK_JOB).Add(func(e *core.ModelEvent) error {
		// Transcription jobs only
		updatedJob := record.LoadBlockJob(e.Model.(*models.Record))
		if updatedJob.Type() != record.Transcription {
			return nil
		}

		// Job complete events only
		if updatedJob.Status() != record.Complete {
			return nil
		}
		prevUpdatedJob := record.LoadBlockJob(updatedJob.Record().OriginalCopy())
		if prevUpdatedJob.Status() == record.Complete {
			return nil
		}

		collection, err := app.Dao().FindCollectionByNameOrId(COLLECTION_BLOCK_JOB)
		if err != nil {
			return err
		}

		form, err := record.NewExportBlockJobForm(record.NewExportBlockJobFormConfig{
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

	jobs := make(chan ExportWorkerJob)
	results := make(chan string)

	for w := 1; w <= 10; w++ {
		go exportWorker(w, jobs, results, app)
	}

	// On export job creation, queue it for processing
	app.OnModelAfterCreate(COLLECTION_BLOCK_JOB).Add(func(e *core.ModelEvent) error {
		// Flags are resolved (it seems) on app.Start(), so this check has been
		// added inside the hook, rather than preventing the hook from being
		// created, as that happens before app.Start() is called.
		if *skipWorkers {
			return nil
		}

		blockJob := record.LoadBlockJob(e.Model.(*models.Record))
		if blockJob.Type() != record.Export {
			return nil
		}
		if blockJob.Status() != record.Waiting {
			return fmt.Errorf("Job %s created with a status other than waiting", blockJob.ID())
		}

		jobs <- ExportWorkerJob{
			BlockJobId: blockJob.ID(),
			BlockId:    blockJob.Block(),
		}

		return nil
	})
}

type ExportWorkerJob struct {
	BlockJobId string
	BlockId    string
}

func exportWorker(id int, jobs <-chan ExportWorkerJob, results chan<- string, app core.App) {
	for j := range jobs {
		fmt.Println("export worker", id, "started block job", j.BlockJobId, "for block", j.BlockId)

		runner := job.NewExportJobRunner(j.BlockJobId, j.BlockId, app)
		err := runner.Run()
		if err != nil {
			fmt.Println("export worker", id, "errored running job", j.BlockJobId, "for block", j.BlockId, "with error", err)
			continue
		}

		// results <- "done"
		fmt.Println("export worker", id, "finished job", j.BlockJobId, "for block", j.BlockId)
	}
}
