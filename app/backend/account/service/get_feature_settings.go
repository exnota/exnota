package service

import (
	"exnota.com/backend/account"
	lib "exnota.com/backend/lib/account"
	"github.com/pocketbase/pocketbase/core"
)

type getUserFeatureSettings struct {
	app     core.App
	fetcher account.UserFeatureSettingsFetcher
}

func NewGetUserFeatureSettings(
	app core.App,
	fetcher account.UserFeatureSettingsFetcher,
) lib.GetFeatureSettings {
	return &getUserFeatureSettings{
		app,
		fetcher,
	}
}

func (gufs *getUserFeatureSettings) GetExnotaSettings(
	feature lib.FeatureNameID,
	user string,
) (lib.ExnotaFeatureSettings, error) {
	result, err := gufs.fetcher.FetchExnotaSettings(feature, user)
	if err != nil {
		return nil, err
	}
	return result, nil
}
