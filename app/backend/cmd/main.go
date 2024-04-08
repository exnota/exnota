package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"exnota.com/backend/api"
	block_api "exnota.com/backend/block/api"
	block_data "exnota.com/backend/block/data"
	"exnota.com/backend/cmd/config"
	integ_api "exnota.com/backend/integration/api"
	integ_data "exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service"
	"exnota.com/backend/job"
	_ "exnota.com/backend/migrations"
	user_api_hooks "exnota.com/backend/user/api"
	"github.com/caarlos0/env"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
)

func main() {
	cfg := config.Config{}
	err := env.Parse(&cfg)
	if err != nil {
		panic(err)
	}

	app := pocketbase.New()

	// Custom flags
	//
	// Note: These are not loaded until *after* app.Start(), so pass values as
	// pointers that are read after app.Start() is called (e.g. when a hook
	// is called).
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

	initJobWorker(app, &skipWorkersCmd)
	bindRequestAndRecordHooks(app, cfg)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

const (
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

func initJobWorker(app core.App, skipWorkers *bool) {
	jobQueue := job.NewBlockJobQueue(app)
	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		if *skipWorkers {
			return nil
		}
		return jobQueue.Start()
	})
}

func bindRequestAndRecordHooks(app core.App, cfg config.Config) {
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
	block_data.NewBlockDataRules(app).ApplyHooks()

	// Job workflow
	job.NewBlockJobWorkflow(app).ApplyHooks()

	// API rules
	integ_api.NewIntegrationRequestHooks(app, integ_api.NotionCredentials{
		ClientId: cfg.NotionOAuthClientID,
		Secret:   cfg.NotionOAuthClientSecret,
	}).Apply()
	integ_api.NewIntegrationNotionObjectApiRules(app).ApplyHooks()
	integ_api.NewIntegrationDestinationApiRules(app).ApplyHooks()
	block_api.NewDestinationApiRules(app, integrationDestinationSync.Sync).ApplyHooks()
	block_api.NewBlockApiRules(app).ApplyHooks()

	// Custom endpoints
	integ_api.NewIntegrationEndpointHooks(app, integ_api.IntegrationEndpointConfig{
		BasePath:               cfg.BasePath,
		NotionClientID:         cfg.NotionOAuthClientID,
		NotionRedirectBasePath: cfg.NotionRedirectBasePath,
	}).Apply()

	// Old rules, need extracting/refactoring
	setBlockJobInvariants(app)
}

func setGlobalDeleteRules(app core.App) {
	// deleting not allowed on any collection
	//
	// set on request hook so HTTP response is as expected
	app.OnRecordBeforeDeleteRequest().Add(func(e *core.RecordDeleteEvent) error {
		return api.NewMethodNotAllowedError("Cannot delete. Archive instead.", nil)
	})

	// set on model hook to catch accidental non-api usage
	app.OnModelBeforeDelete().Add(func(e *core.ModelEvent) error {
		return api.NewMethodNotAllowedError("Cannot delete. Archive instead.", nil)
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
