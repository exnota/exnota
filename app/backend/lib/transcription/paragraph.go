package whisper

import (
	"strings"

	"github.com/neurosnap/sentences/english"
)

func toParagraphs(transcription string) ([]string, error) {
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
