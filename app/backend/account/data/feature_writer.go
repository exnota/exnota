package data

import (
	"database/sql"
	"errors"
	"fmt"
	"log/slog"

	"exnota.com/backend/account"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type FeatureWriter interface {
	CreateIfDoNotExist(features ...account.Feature) error
}

type featureWriter struct {
	app core.App
}

func NewFeatureWriter(app core.App) FeatureWriter {
	return &featureWriter{
		app,
	}
}

func (f *featureWriter) CreateIfDoNotExist(features ...account.Feature) error {
	err := f.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		for _, feature := range features {
			_, err := txDao.FindFirstRecordByData(
				account.CollectionFeature,
				account.FeatureFieldNameID,
				string(feature.NameID()),
			)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				slog.Error("Error finding feature", "error", err, "nameID", feature.NameID())
				return err
			} else if errors.Is(err, sql.ErrNoRows) {
				slog.Info("Creating feature", "nameID", feature.NameID())
				err := feature.SubmitAndValidate(txDao)
				if err != nil {
					slog.Error("Error submitting feature", "error", err, "nameID", feature.NameID())
					return fmt.Errorf("error submitting feature %v: %w", feature.NameID(), err)
				}
			} else {
				slog.Info("Feature already exists", "nameID", feature.NameID())
			}
		}
		return nil
	})
	if err != nil {
		slog.Error("Error creating features", "error", err)
		return fmt.Errorf("error creating features: %w", err)
	}

	return nil
}
