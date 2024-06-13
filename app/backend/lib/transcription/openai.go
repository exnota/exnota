package whisper

import (
	"context"
	"fmt"
	"log/slog"

	openai "github.com/sashabaranov/go-openai"
)

type TranscriptionGeneratorOpenAI interface {
	Generate(fullPath string) ([]string, error)
}

type transcriptionGeneratorOpenAI struct {
	openAIKey string
}

func NewTranscriptionGeneratorOpenAI(
	openAIKey string,
) TranscriptionGeneratorOpenAI {
	return &transcriptionGeneratorOpenAI{
		openAIKey,
	}
}

func (tg *transcriptionGeneratorOpenAI) Generate(fullPath string) ([]string, error) {
	slog.Info("Generating transcription with openai")

	client := openai.NewClient(tg.openAIKey)
	resp, err := client.CreateTranscription(
		context.Background(),
		openai.AudioRequest{
			Model:    openai.Whisper1,
			FilePath: fullPath,
		},
	)
	if err != nil {
		slog.Error("Error generating transcription for openai", "error", err)
		return nil, fmt.Errorf("error generating transcription for openai: %w", err)
	}

	paragraphs, err := toParagraphs(resp.Text)
	if err != nil {
		slog.Error("Error converting transcription to paragraphs", "error", err)
		return nil, fmt.Errorf("error converting transcription to paragraphs: %w", err)
	}

	return paragraphs, nil
}
