package account

type FeatureNameID string

// When adding, also add migration to create in database.
const (
	ExnotaFeatureVoiceNoteNameID FeatureNameID = "VOICE_NOTE"
)
