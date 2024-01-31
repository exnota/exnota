package record

import (
	"testing"

	"exnota.com/backend/test"
)

func TestNewExportBlockJob(t *testing.T) {
	app := test.TestApp()
	defer app.Cleanup()

	collection, err := app.Dao().FindCollectionByNameOrId("block_job")
	if err != nil {
		t.Fatal(err)
	}

	form, err := NewExportBlockJobForm(NewExportBlockJobFormConfig{
		Collection: collection,
		App:        app,
		BlockId:    "block1--15chars",
		UserId:     "user1-15char-id",
	})
	if err != nil {
		t.Errorf("NewExportBlockJob() error = %v", err)
		return
	}

	if form.Data()["status"] != "waiting" {
		t.Errorf("NewExportBlockJob() form status = %v, want %v", form.Data()["status"], "waiting")
	}
	if form.Data()["type"] != "export" {
		t.Errorf("NewExportBlockJob() form type = %v, want %v", form.Data()["type"], "export")
	}
	if form.Data()["block"] != "block1--15chars" {
		t.Errorf("NewExportBlockJob() form block = %v, want %v", form.Data()["block"], "block1--15chars")
	}
	if form.Data()["user"] != "user1-15char-id" {
		t.Errorf("NewExportBlockJob() form user = %v, want %v", form.Data()["user"], "user1-15char-id")
	}

	if err := form.Submit(); err != nil {
		t.Fatal(err)
	}
}
