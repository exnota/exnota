package job

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"exnota.com/backend/block"
	"exnota.com/backend/job/data"
	"exnota.com/backend/lib/pb_file"
	"exnota.com/backend/lib/whisper"
	"github.com/neurosnap/sentences/english"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

const tempTranscriptionDir = "transcription"

type TranscriptionJobRunner interface {
	RunnableBlockJob
}

type transcriptionJobRunner struct {
	app     core.App
	whisper whisper.Whisper
}

func NewTranscriptionJobRunner(app core.App, whisper whisper.Whisper) TranscriptionJobRunner {
	return &transcriptionJobRunner{
		app,
		whisper,
	}
}

// run method
func (j *transcriptionJobRunner) Run(job data.BlockJob, app core.App) (data.Summary, error) {
	slog.Info(
		"[transcription job runner] Running job",
		"job",
		job.ID(),
		"block",
		job.Block(),
	)
	fileInfo, err := j.getFileInfo(job.Block())
	if err != nil {
		return nil, err
	}

	convertedFileInfo, err := j.convertAudio(fileInfo)
	if err != nil {
		return nil, err
	}

	result, err := j.transcribe(*convertedFileInfo)
	if err != nil {
		return nil, err
	}

	err = j.saveTranscription(result, job.Block())
	if err != nil {
		return nil, err
	}

	slog.Info(
		"[transcription job runner] Job completed",
		"job",
		job.ID(),
		"block",
		job.Block(),
	)
	return data.NewSummaryCompleteEmpty(), nil
}

type FileInfo struct {
	name     string
	fullPath string
}

func (j *transcriptionJobRunner) getFileInfo(blockId string) (*FileInfo, error) {
	block, err := j.app.Dao().FindRecordById("block", blockId)
	if err != nil {
		return nil, err
	}
	fileName := block.GetString("file")
	filePath := pb_file.Path(j.app, block, fileName)

	return &FileInfo{
		name:     fileName,
		fullPath: filePath,
	}, nil
}

type ConvertedFileInfo struct {
	fullPath string
}

func (j *transcriptionJobRunner) convertAudio(fileInfo *FileInfo) (*ConvertedFileInfo, error) {
	rootTempDir := filepath.Join(j.app.DataDir(), core.LocalTempDirName)
	if err := os.MkdirAll(rootTempDir, os.ModePerm); err != nil {
		return nil, err
	}
	// Ensure transcriptions subdir also exists
	convertedTempDir := filepath.Join(rootTempDir, tempTranscriptionDir)
	if err := os.MkdirAll(convertedTempDir, os.ModePerm); err != nil {
		return nil, err
	}

	convertedName := strings.TrimSuffix(
		fileInfo.name,
		filepath.Ext(fileInfo.name),
	) + "-converted.wav"
	convertedPath := path.Join(convertedTempDir, convertedName)
	fmt.Println("convertedPath", convertedPath)

	cmnd := exec.Command("ffmpeg", "-y" /* overwrite */, "-i", fileInfo.fullPath,
		"-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", convertedPath)
	out, err := cmnd.CombinedOutput()
	fmt.Println("Audio file conversion:")
	fmt.Println(string(out))
	if err != nil {
		return nil, err
	}
	return &ConvertedFileInfo{
		fullPath: convertedPath,
	}, nil
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

func (j *transcriptionJobRunner) transcribe(
	convertedFileInfo ConvertedFileInfo,
) (*TranscriptionResult, error) {
	cmnd := j.whisper.Command(convertedFileInfo.fullPath)
	out, err := cmnd.CombinedOutput()
	fmt.Println("Transcribe:")
	fmt.Println(string(out))
	if err != nil {
		return nil, err
	}

	raw, err := os.ReadFile(convertedFileInfo.fullPath + ".json")
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

	return &result, nil
}

func (j *transcriptionJobRunner) saveTranscription(
	result *TranscriptionResult,
	blockId string,
) error {
	err := j.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		// TODO: Refactor to use repo
		blockRecord, err := txDao.FindRecordById("block", blockId)
		if err != nil {
			return err
		}

		b, err := block.LoadVoiceNoteBlock(blockRecord, j.app)
		if err != nil {
			return err
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

		err = b.SetTranscription(paragraphs)
		if err != nil {
			return err
		}

		err = b.ValidateAndSubmit(txDao)
		if err != nil {
			return err
		}

		return nil
	})
	if err != nil {
		return err
	}

	return nil
}
