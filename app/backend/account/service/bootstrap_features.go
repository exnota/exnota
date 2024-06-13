package service

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/account"
	"exnota.com/backend/account/data"
	lib_account "exnota.com/backend/lib/account"
	"github.com/pocketbase/pocketbase/core"
)

type BootstrapFeatures interface {
	ApplyHooks()
}

type bootstrapFeatures struct {
	app           core.App
	featureWriter data.FeatureWriter
}

func NewBootstrapFeatures(app core.App, featureWriter data.FeatureWriter) BootstrapFeatures {
	return &bootstrapFeatures{
		app, featureWriter,
	}
}

func (b *bootstrapFeatures) ApplyHooks() {
	b.app.OnAfterBootstrap().Add(func(e *core.BootstrapEvent) error {
		// Note:
		// - IDs are hardcoded in case it makes life easier when applying
		// changes across multiple environments. However features should be
		// referenced by nameID where possible.

		// Feature: Exnota Voice Note
		exnotaVoiceNoteID := "6cigtgygahslau5"
		exnotaVoiceNoteSettings := lib_account.VoiceNoteSettings{
			Service: lib_account.VoiceNoteServiceOpenAI,
		}
		exnotaVoiceNote, err := account.CreateExnotaVoiceNoteFeature(
			b.app, exnotaVoiceNoteID, exnotaVoiceNoteSettings,
		)
		if err != nil {
			return err
		}
		features := []account.Feature{exnotaVoiceNote}

		// Persist
		err = b.featureWriter.CreateIfDoNotExist(features...)
		if err != nil {
			slog.Error("Error creating features", "error", err)
			return fmt.Errorf("error creating features: %w", err)
		}

		return nil
	})
}
