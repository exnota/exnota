package whisper

type TranscriptionGeneratorWhisperLargeV2 interface {
	Generate(fullPath string) ([]string, error)
}

type transcriptionWhisperGeneratorLargeV2 struct {
	whisperCommand WhisperCommand
}

func NewTranscriptionWhisperGeneratorLargeV2(
	whisperCommand WhisperCommand,
) TranscriptionGeneratorWhisperLargeV2 {
	return &transcriptionWhisperGeneratorLargeV2{
		whisperCommand,
	}
}

func (g *transcriptionWhisperGeneratorLargeV2) Generate(fullPath string) ([]string, error) {
	return generate(g.whisperCommand, ModelPathWhisperLargeV2, fullPath)
}
