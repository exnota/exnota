package test

import (
	"path/filepath"
	"runtime"

	"github.com/pocketbase/pocketbase/tests"
)

var (
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
