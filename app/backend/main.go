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

	// TODO: Remove?
	// serves static files from the provided public dir (if exists)
	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET("/*", apis.StaticDirectoryHandler(os.DirFS("./pb_public"), false))
		return nil
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

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
