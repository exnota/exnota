package record

import (
	"testing"

	"exnota.com/backend/test"
)

func TestAudioBlockSetters(t *testing.T) {
	app := test.TestApp()
	defer app.Cleanup()

	t.Run("Block with no existing transcription", func(t *testing.T) {
		// Block with no existing transcription
		rec, err := app.Dao().FindRecordById("block", "block9--15chars", nil)
		if err != nil {
			t.Fatal(err)
		}
		block, err := NewAudioBlock(rec)
		if err != nil {
			t.Fatal(err)
		}

		t.Run("SetTitle", func(t *testing.T) {
			block.SetTitle("updated title")
			if rec.GetString("title") != "updated title" {
				t.Errorf("Expected title to be updated, got %v", rec.GetString("title"))
			}
		})

		t.Run("SetTranscription", func(t *testing.T) {
			err = block.SetTranscription([]string{"new paragraph 1", "new paragraph 2"})
			if err != nil {
				t.Errorf("Expected transcription to be set, got error %v", err)
			}
			if rec.GetString("audio") != "{\"transcription\":[\"new paragraph 1\",\"new paragraph 2\"]}" {
				t.Errorf("Expected audio to be marshalled correctly, but got %v", rec.GetString("audio"))
			}
		})
	})

	t.Run("Block with existing transcription", func(t *testing.T) {
		// Block with existing transcription
		rec, err := app.Dao().FindRecordById("block", "block10-15chars", nil)
		if err != nil {
			t.Fatal(err)
		}
		block, err := NewAudioBlock(rec)
		if err != nil {
			t.Fatal(err)
		}

		err = block.SetTranscription([]string{"new paragraph 1", "new paragraph 2"})
		if err != nil {
			t.Errorf("Expected transcription to be set, got error %v", err)
		}

		if rec.GetString("audio") != "{\"transcription\":[\"new paragraph 1\",\"new paragraph 2\"]}" {
			t.Errorf("Expected new transcription to be marshalled correctly, but got %v", rec.GetString("audio"))
		}

	})

}
