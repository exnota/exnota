package test

import (
	"path/filepath"
	"runtime"

	"github.com/pocketbase/pocketbase/tests"
)

var (
	// Get test data dir relative to this file, so tests can be run from project
	// root or any subdirectory.
	_, b, _, _  = runtime.Caller(0)
	basepath    = filepath.Dir(b)
	testDataDir = filepath.Join(basepath, "../pb_data_test")
)

func TestApp() *tests.TestApp {
	app, err := tests.NewTestApp(testDataDir)
	app.DataDir()
	if err != nil {
		panic(err)
	}
	return app
}
