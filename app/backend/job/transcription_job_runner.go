package job

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	block_data "exnota.com/backend/block/data"
	"exnota.com/backend/job/data"
	whisper "exnota.com/backend/lib"
	"exnota.com/backend/lib/pb_file"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

const tempTranscriptionDir = "transcription"

type TranscriptionJobRunner interface {
	RunnableBlockJob
}

type transcriptionJobRunner struct {
	app core.App
}

func NewTranscriptionJobRunner(app core.App) TranscriptionJobRunner {
	return &transcriptionJobRunner{
		app: app,
	}
}

// run method
func (j *transcriptionJobRunner) Run(job data.BlockJob, app core.App) (data.Summary, error) {
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
	cmnd := whisper.Command(convertedFileInfo.fullPath)
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
		blockRecord, err := txDao.FindRecordById("block", blockId)
		if err != nil {
			return err
		}

		block, err := block_data.NewVoiceNoteBlock(blockRecord)
		if err != nil {
			return err
		}

		transcription := ""
		for i := 0; i < len(result.Transcription); i++ {
			transcription += result.Transcription[i].Text
		}
		transcription = strings.Trim(transcription, " ")
		err = block.SetTranscription([]string{transcription})
		if err != nil {
			return err
		}

		// TODO: Should this be updated to use forms.NewRecordUpsert so it has validations?
		// https://pocketbase.io/docs/go-records/#update-existing-record
		err = txDao.SaveRecord(blockRecord)
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
