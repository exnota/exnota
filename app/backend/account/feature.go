package account

import (
	"log/slog"

	lib "exnota.com/backend/lib/account"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionFeature    = "feature"
	FeatureFieldNameID   = "nameID"
	FeatureFieldProduct  = "product"
	FeatureFieldSettings = "settings"
)

type Feature interface {
	NameID() lib.FeatureNameID

	SubmitAndValidate(txDao *daos.Dao) error
}

type feature struct {
	app    core.App
	record *models.Record
}

func CreateExnotaVoiceNoteFeature(
	app core.App,
	id string,
	settings interface{},
) (Feature, error) {
	collection, err := app.Dao().FindCollectionByNameOrId(CollectionFeature)
	if err != nil {
		slog.Error("Error finding collection", "error", err, "collection", CollectionFeature)
		return nil, err
	}

	record := models.NewRecord(collection)
	record.SetId(id)
	record.Set(FeatureFieldNameID, string(lib.ExnotaFeatureVoiceNoteNameID))
	record.Set(FeatureFieldProduct, string(lib.ProductExnota))
	record.Set(FeatureFieldSettings, settings)

	return &feature{app, record}, nil
}

func (f *feature) NameID() lib.FeatureNameID {
	return lib.FeatureNameID(f.record.GetString(FeatureFieldNameID))
}

func (f *feature) SubmitAndValidate(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(f.app, f.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}
