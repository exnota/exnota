package data

import (
	"fmt"
	"log/slog"

	"exnota.com/backend/account"
	lib "exnota.com/backend/lib/account"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
)

type userFeatureSettingsFetcher struct {
	app core.App
}

func NewUserFeatureSettingsFetcher(app core.App) account.UserFeatureSettingsFetcher {
	return &userFeatureSettingsFetcher{
		app,
	}
}

func (f *userFeatureSettingsFetcher) FetchExnotaSettings(
	featureNameID lib.FeatureNameID,
	user string,
) (lib.ExnotaFeatureSettings, error) {
	filter, err := filter.CreateAndFilter(
		filter.Field{
			Name:  account.UserFeatureSettingsFieldProduct,
			Op:    filter.OpEquals,
			Value: string(lib.ProductExnota),
		},
		filter.Field{
			Name:  account.UserFeatureSettingsFieldFeatureNameID,
			Op:    filter.OpEquals,
			Value: string(featureNameID),
		},
		filter.Field{
			Name:  account.UserFeatureSettingsFieldUser,
			Op:    filter.OpEquals,
			Value: user,
		},
	)
	if err != nil {
		slog.Error("error creating filter", "err", err)
		return nil, fmt.Errorf("error creating filter: %w", err)
	}
	record, err := f.app.Dao().FindFirstRecordByFilter(
		account.CollectionUserFeatureSettings,
		filter.Filter,
		filter.Params,
	)
	if err != nil {
		slog.Error("error finding first record by filter", "err", err)
		return nil, fmt.Errorf("error finding first record by filter: %w", err)
	}

	ufs, err := account.LoadUserFeatureSettings(record)
	if err != nil {
		slog.Error("error loading user feature settings", "err", err)
		return nil, fmt.Errorf("error loading user feature settings: %w", err)
	}

	settings, err := ufs.Settings()
	if err != nil {
		slog.Error("error getting settings", "err", err)
		return nil, fmt.Errorf("error getting settings: %w", err)
	}

	return settings, nil
}
