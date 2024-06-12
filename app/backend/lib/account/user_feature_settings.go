package account

// Exnota

type ExnotaFeatureSettings interface{}

type GetFeatureSettings interface {
	GetExnotaSettings(feature FeatureNameID, user string) (ExnotaFeatureSettings, error)
}

// Voice note feature

type VoiceNoteService string

const (
	// Keep these in sync with 'oneof' validation in VoiceNoteSettings
	VoiceNoteServiceWhisperLargeV3 VoiceNoteService = "whisper-large-v3"
	VoiceNoteServiceWhisperLargeV2 VoiceNoteService = "whisper-large-v2"
	VoiceNoteServiceOpenAI         VoiceNoteService = "openai"
)

type VoiceNoteSettings struct {
	Service VoiceNoteService `json:"service" validate:"required,oneof=whisper-large-v3 openai"`
}
