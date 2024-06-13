package whisper

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strings"
)

type TranscriptionGeneratorWhisperLargeV3 interface {
	Generate(fullPath string) ([]string, error)
}

type transcriptionWhisperGeneratorLargeV3 struct {
	whisperCommand WhisperCommand
}

func NewTranscriptionWhisperGeneratorLargeV3(
	whisperCommand WhisperCommand,
) TranscriptionGeneratorWhisperLargeV3 {
	return &transcriptionWhisperGeneratorLargeV3{
		whisperCommand,
	}
}

func (g *transcriptionWhisperGeneratorLargeV3) Generate(fullPath string) ([]string, error) {
	// Transcribe with whisper large v3
	return generate(g.whisperCommand, ModelPathWhisperLargeV2, fullPath)
}

type TranscriptionResult struct {
	Transcription []Transcription `json:"transcription"`
}

type Transcription struct {
	Timestamps Timestamp `json:"timestamps"`
	Text       string    `json:"text"`
}

type Timestamp struct {
	From string `json:"from"`
	To   string `json:"to"`
}

func generate(
	whisperCommand WhisperCommand,
	modelPath ModelPath,
	fullPath string,
) ([]string, error) {
	cmnd := whisperCommand.Command(modelPath, fullPath)
	out, err := cmnd.CombinedOutput()
	fmt.Println("Transcribe:")
	fmt.Println(string(out))
	if err != nil {
		return nil, err
	}

	raw, err := os.ReadFile(fullPath + ".json")
	if err != nil {
		return nil, err
	}
	fmt.Println("raw json", string(raw))

	var result TranscriptionResult
	err = json.Unmarshal(raw, &result)
	if err != nil {
		return nil, err
	}

	for i := 0; i < len(result.Transcription); i++ {
		transcription := result.Transcription[i]
		fmt.Println(transcription.Text)
	}

	transcription := ""
	for i := 0; i < len(result.Transcription); i++ {
		transcription += result.Transcription[i].Text
	}
	transcription = strings.Trim(transcription, " ")

	paragraphs, err := toParagraphs(transcription)
	if err != nil {
		slog.Error("Error converting transcription to paragraphs", "error", err)
		return nil, fmt.Errorf("error converting transcription to paragraphs: %w", err)
	}

	return paragraphs, nil
}
