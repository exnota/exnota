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

	t.Run("Status is set", func(t *testing.T) {
		if form.Data()["status"] != "waiting" {
			t.Errorf("NewExportBlockJob() form status = %v, want %v", form.Data()["status"], "waiting")
		}
	})

	t.Run("Type is set", func(t *testing.T) {
		if form.Data()["type"] != "export" {
			t.Errorf("NewExportBlockJob() form type = %v, want %v", form.Data()["type"], "export")
		}
	})

	t.Run("Block is set", func(t *testing.T) {
		if form.Data()["block"] != "block1--15chars" {
			t.Errorf("NewExportBlockJob() form block = %v, want %v", form.Data()["block"], "block1--15chars")
		}
	})

	t.Run("User is set", func(t *testing.T) {
		if form.Data()["user"] != "user1-15char-id" {
			t.Errorf("NewExportBlockJob() form user = %v, want %v", form.Data()["user"], "user1-15char-id")
		}
	})

	t.Run("Form can be submitted", func(t *testing.T) {
		if err := form.Submit(); err != nil {
			t.Fatal(err)
		}
	})
}
