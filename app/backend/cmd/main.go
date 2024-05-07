package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"exnota.com/backend/api"
	"exnota.com/backend/block"
	block_api "exnota.com/backend/block/api"
	block_data "exnota.com/backend/block/data"
	block_event "exnota.com/backend/block/event"
	"exnota.com/backend/cmd/config"
	"exnota.com/backend/event"
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
	//
	// Same caveats as event workflows below, for some of these.
	integ_data.NewIntegrationNotionObjectHooks(app).ApplyHooks()
	integ_data.NewIntegrationDestinationDataRules(app).ApplyHooks()
	block.NewWorkspaceDataRules(app, block_data.NewWorkspaceFetcher(app)).ApplyHooks()
	integrationDestinationSync := service.NewIntegrationDestinationSync(app)
	block_data.NewDestinationDataRules(app).ApplyHooks()
	block.NewBlockDataRules(app,
		block_data.NewBlockFetcher(app),
		block_data.NewDestinationFetcher(app),
	).ApplyHooks()

	// Event workflows
	//
	// Haven't figured out a pattern I like here yet. To use a PocketBase hook
	// that's triggered in one domain and performs an action in another domain,
	// you need to reference both domains, which adds a lot of
	// cross-dependencies.
	//
	// But at the same time I don't want to spend a long time creating
	// abstractions.
	//
	// I've taken different approaches below (and possibly elsewhere, e.g. in
	// data rules). Hopefully I settle on a pattern soon and can refactor.
	job.NewBlockJobWorkflow(app).ApplyHooks()
	// Block status listener should go after job workflow, as it should have
	// access to new jobs that are created in sequence. E.g. it should
	// know about the second export job, otherwise it may think all exporting
	// is complete.
	block_event.NewBlockStatusListener(app).ApplyHooks()
	// The idea with this pattern is to isolate coupling to a separate folder
	// (i.e. the 'event' folder). This is basically the same approach as the
	// block job workflow above. This would at least help developers know that
	// changes to one domain will only affect that domain and the event folder.
	event.NewIntegrationListener(app).ApplyHooks()

	// API rules
	integ_api.NewIntegrationRequestHooks(app, integ_api.NotionCredentials{
		ClientId: cfg.NotionOAuthClientID,
		Secret:   cfg.NotionOAuthClientSecret,
	}).Apply()
	integ_api.NewIntegrationNotionObjectApiRules(app).ApplyHooks()
	integ_api.NewIntegrationDestinationApiRules(app).ApplyHooks()
	workspaceFetcher := block_data.NewWorkspaceFetcher(app)
	block_api.NewDestinationCreateAPI(
		app,
		integrationDestinationSync.Sync,
		workspaceFetcher,
	).ApplyHooks()
	block_api.NewBlockCreateAPI(app).ApplyHooks()
	block_api.NewWorkspaceCreateAPI(app, workspaceFetcher).ApplyHooks()
	block_api.NewWorkspaceUpdateAPI(app, workspaceFetcher).ApplyHooks()

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
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).
		Add(func(e *core.RecordUpdateEvent) error {
			existingRecord, err := app.Dao().
				FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
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
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).
		Add(func(e *core.RecordUpdateEvent) error {
			existingRecord, err := app.Dao().
				FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
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
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).
		Add(func(e *core.RecordUpdateEvent) error {
			existingRecord, err := app.Dao().
				FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
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
	app.OnRecordBeforeCreateRequest(COLLECTION_BLOCK_JOB).
		Add(func(e *core.RecordCreateEvent) error {
			blockId := e.Record.GetString(BLOCK_JOB_FIELD_BLOCK)
			block, err := app.Dao().FindRecordById("block", blockId, nil)
			if err != nil {
				return err
			}

			blockUserId := block.GetString("user")
			jobUserId := e.Record.GetString(BLOCK_JOB_FIELD_USER)

			if blockUserId != jobUserId {
				return apis.NewBadRequestError("Block job user must match block user", nil)
			}

			return nil
		})
}
