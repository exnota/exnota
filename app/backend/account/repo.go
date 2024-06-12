package account

import (
	lib "exnota.com/backend/lib/account"
)

type UserFeatureSettingsFetcher interface {
	FetchExnotaSettings(
		featureNameID lib.FeatureNameID,
		user string,
	) (lib.ExnotaFeatureSettings, error)
}
