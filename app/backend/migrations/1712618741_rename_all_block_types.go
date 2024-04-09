package migrations

import (
	"log/slog"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/daos"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(db dbx.Builder) error {
		return daos.New(db).RunInTransaction(func(txDao *daos.Dao) error {
			// update audio to voice-note
			audioRecords, err := txDao.FindRecordsByFilter(
				"block",
				"type = \"audio\"",
				"",
				0,
				0,
			)
			if err != nil {
				return err
			}

			slog.Info("Updating all 'audio' blocks to 'voice-note'", "count", len(audioRecords))
			for _, audioRecord := range audioRecords {
				audioRecord.Set("type", "voice-note")
				txDao.SaveRecord(audioRecord)
			}

			// update text to text-note
			textRecords, err := txDao.FindRecordsByFilter(
				"block",
				"type = \"text\"",
				"",
				0,
				0,
			)
			if err != nil {
				return err
			}
			slog.Info("Updating all 'text' blocks to 'text-note'", "count", len(textRecords))
			for _, textRecord := range textRecords {
				textRecord.Set("type", "text-note")
				txDao.SaveRecord(textRecord)
			}

			return nil
		})

	}, func(db dbx.Builder) error {
		// Rollback changing type 'text' to 'text-note'
		return daos.New(db).RunInTransaction(func(txDao *daos.Dao) error {
			// update text-note to text
			textRecords, err := txDao.FindRecordsByFilter(
				"block",
				"type = \"text-note\"",
				"",
				0,
				0,
			)
			if err != nil {
				return err
			}
			slog.Info("Rollback all 'text-note' blocks to 'text'", "count", len(textRecords))
			for _, textRecord := range textRecords {
				textRecord.Set("type", "text")
				txDao.SaveRecord(textRecord)
			}

			// update voice-note to audio
			voiceRecords, err := txDao.FindRecordsByFilter(
				"block",
				"type = \"voice-note\"",
				"",
				0,
				0,
			)
			if err != nil {
				return err
			}
			slog.Info("Rollback all 'voice-note' blocks to 'audio'", "count", len(voiceRecords))
			for _, voiceRecord := range voiceRecords {
				voiceRecord.Set("type", "audio")
				txDao.SaveRecord(voiceRecord)
			}

			return nil
		})
	})
}
