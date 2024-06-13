package account

import (
	"errors"

	lib "exnota.com/backend/lib/account"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionUserFeatureSettings         = "user_feature_settings"
	UserFeatureSettingsFieldProduct       = "product"
	UserFeatureSettingsFieldFeatureNameID = "featureNameID"
	UserFeatureSettingsFieldUser          = "user"
	UserFeatureSettingsFieldSettings      = "settings"
)

type UserFeatureSettings interface {
	FeatureNameID() lib.FeatureNameID
	Settings() (lib.ExnotaFeatureSettings, error)
}

type userFeatureSettings struct {
	record *models.Record
}

func LoadUserFeatureSettings(model models.Model) (UserFeatureSettings, error) {
	record, ok := model.(*models.Record)
	if !ok {
		return nil, errors.New("invalid model")
	}

	return &userFeatureSettings{record: record}, nil
}

func (u *userFeatureSettings) FeatureNameID() lib.FeatureNameID {
	return lib.FeatureNameID(u.record.GetString(UserFeatureSettingsFieldFeatureNameID))
}

func (u *userFeatureSettings) Settings() (lib.ExnotaFeatureSettings, error) {
	// Detect if nil.
	//
	// Cannot simply use UnmarshalJSONField because if the field is nil, it will
	// throw an error even though nil is a valid value.
	raw := u.record.Get(UserFeatureSettingsFieldSettings).(types.JsonRaw)
	val, err := raw.Value()
	if err != nil {
		return nil, err
	}
	// The Admin UI sends "null". To make comparisons easier, treat this the
	// same as nil.
	if val == nil || val == "null" {
		return nil, nil
	}

	// Unmarshal
	switch u.FeatureNameID() {
	case lib.ExnotaFeatureVoiceNoteNameID:
		var settings lib.VoiceNoteSettings
		err = u.record.UnmarshalJSONField(UserFeatureSettingsFieldSettings, &settings)
		if err != nil {
			return nil, err
		}
		return settings, err
	default:
		return nil, errors.New("unsupported feature")
	}
}
