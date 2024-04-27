package data

import (
	"testing"

	"exnota.com/backend/test"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

func TestIntegration(t *testing.T) {
	app := test.TestApp()
	defer app.Cleanup()

	t.Run("ValidateAndSubmit", func(t *testing.T) {
		collection, err := app.Dao().FindCollectionByNameOrId(CollectionIntegration)
		if err != nil {
			t.Fatal(err)
		}

		newRecord := models.NewRecord(collection)
		newForm := forms.NewRecordUpsert(app, newRecord)
		err = newForm.LoadData(map[string]any{
			"id":     "integ1-15charid",
			"type":   string(TypeNotion),
			"user":   "user1-15char-id",
			"status": IntegrationStatusConnected,
		})
		if err != nil {
			t.Fatal(err)
		}
		err = newForm.Submit()
		if err != nil {
			t.Fatal(err)
		}

		t.Run("Errors on invalid status", func(t *testing.T) {
			record, err := app.Dao().FindRecordById(CollectionIntegration, "integ1-15charid", nil)
			if err != nil {
				t.Fatal(err)
			}
			if record == nil {
				t.Fatal("Expected record to be found")
			}

			integration, err := LoadIntegration(record, app)
			if err != nil {
				t.Fatal(err)
			}
			integration.SetStatus("invalid")

			err = integration.ValidateAndSubmit(app.Dao())
			if err == nil {
				t.Fatal("Expected error, got nil")
			}
		})
		t.Run("Succeeds and persists on valid status", func(t *testing.T) {
			record, err := app.Dao().FindRecordById(CollectionIntegration, "integ1-15charid", nil)
			if err != nil {
				t.Fatal(err)
			}
			if record == nil {
				t.Fatal("Expected record to be found")
			}

			integration, err := LoadIntegration(record, app)
			if err != nil {
				t.Fatal(err)
			}
			integration.SetStatus(IntegrationStatusAccessRevoked)

			err = integration.ValidateAndSubmit(app.Dao())
			if err != nil {
				t.Fatal("Expected success, got error", err)
			}

			updated, err := app.Dao().FindRecordById(CollectionIntegration, "integ1-15charid", nil)
			if err != nil {
				t.Fatal(err)
			}
			if updated == nil {
				t.Fatal("Expected record to be found")
			}
			if updated.GetString(IntegrationFieldStatus) != "access-revoked" {
				t.Fatalf("Expected status to be updated, got %v", updated.GetString(IntegrationFieldStatus))
			}
		})
	})
}
