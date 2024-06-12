package whisper

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/neurosnap/sentences/english"
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
	// Transcribe with whisper large v3
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

	tokenizer, err := english.NewSentenceTokenizer(nil)
	if err != nil {
		panic(err)
	}

	sentenceTokens := tokenizer.Tokenize(transcription)
	sentences := make([]string, len(sentenceTokens))
	for i, token := range sentenceTokens {
		sentences[i] = token.Text
	}
	paragraphs := make([]string, 0)
	batchSize := 3
	numSentences := len(sentences)
	// 3 sentences per paragraph. If the last paragraph is only 1 sentence,
	// append it to the previous paragraph.
	for i := 0; i < numSentences; i += batchSize {
		end := i + batchSize
		if end > numSentences {
			end = numSentences
		}
		batch := sentences[i:end]
		paragraph := strings.Join(batch, " ")
		// Add to the previous paragraph if:
		// 1. It's not the first batch
		// 2. The current batch has only 1 sentence
		// 3. It is the last batch
		if i > 0 && len(batch) == 1 && i+batchSize >= numSentences-1 {
			lastParagraph := paragraphs[len(paragraphs)-1]
			lastParagraph += " " + paragraph
			paragraphs[len(paragraphs)-1] = lastParagraph
		} else {
			paragraphs = append(paragraphs, paragraph)
		}
	}

	return paragraphs, nil
}
