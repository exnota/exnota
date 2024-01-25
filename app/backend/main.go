package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	_ "exnota.com/backend/migrations"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
)

func main() {
	app := pocketbase.New()

	autoMigrate := isAutoMigrate()
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		// enable auto creation of migration files when making collection changes in the Admin UI
		// (the isGoRun check is to enable it only during development)
		Automigrate: autoMigrate,
	})

	bindAppHooks(app)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

const (
	COLLECTION_USER = "users"

	COLLECTION_BLOCK = "block"
	BLOCK_FIELD_TYPE = "type"
	BLOCK_FIELD_USER = "user"
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

func bindAppHooks(app core.App) {
	// serves static files from the provided public dir (if exists)
	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET("/*", apis.StaticDirectoryHandler(os.DirFS("./pb_public"), false))
		return nil
	})

	bindUnauthenticatedHooks(app)
	bindBlockInvariantsHooks(app)
}

func bindUnauthenticatedHooks(app core.App) {
	app.OnRecordsListRequest().Add(func(e *core.RecordsListEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})
	app.OnRecordViewRequest().Add(func(e *core.RecordViewEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})

	app.OnRecordBeforeCreateRequest().Add(func(e *core.RecordCreateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})

	app.OnRecordBeforeUpdateRequest().Add(func(e *core.RecordUpdateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})

	app.OnRecordBeforeDeleteRequest().Add(func(e *core.RecordDeleteEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})
}

func bindBlockInvariantsHooks(app core.App) {
	// type cannot be changed
	app.OnRecordBeforeUpdateRequest().Add(func(e *core.RecordUpdateEvent) error {
		if e.Record.Collection().Name != COLLECTION_BLOCK {
			return nil
		}

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
	app.OnRecordBeforeUpdateRequest().Add(func(e *core.RecordUpdateEvent) error {
		if e.Record.Collection().Name != COLLECTION_BLOCK {
			return nil
		}

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

}
