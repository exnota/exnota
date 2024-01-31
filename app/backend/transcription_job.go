package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/tools/types"
)

const tempTranscriptionDir = "transcription"
const whisperModelsDir = "/whisper/models"
const whisperModelFilename = "ggml-large-v3.bin"

// From https://platform.openai.com/docs/guides/speech-to-text/prompting
const transcriptionPrompt = "Hello, welcome to my lecture."

type transJob struct {
	blockJobId string
	blockId    string
	app        core.App
}

func NewTransJob(blockJobId string, blockId string, app core.App) *transJob {
	return &transJob{
		blockJobId: blockJobId,
		blockId:    blockId,
		app:        app,
	}
}

// run method
func (j *transJob) Run() error {
	err := j.setJobStatus(BLOCK_JOB_STATUS_RUNNING, true, nil)
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	fileInfo, err := j.getFileInfo()
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	convertedFileInfo, err := j.convertAudio(fileInfo)
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	result, err := j.transcribe(*convertedFileInfo)
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	err = j.saveTranscription(result)
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	err = j.setJobStatus(BLOCK_JOB_STATUS_COMPLETE, false, nil)
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	return nil
}

type FileInfo struct {
	name     string
	dir      string
	fullPath string
}

func (j *transJob) setJobStatusError(jobErr error) error {
	return j.setJobStatus(BLOCK_JOB_STATUS_ERROR, false, jobErr)
}

func (j *transJob) setJobStatus(status string, validateWaiting bool, jobErr error) error {
	err := j.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		blockJob, err := txDao.FindRecordById(COLLECTION_BLOCK_JOB, j.blockJobId)
		if err != nil {
			return err
		}

		if validateWaiting && blockJob.GetString(BLOCK_JOB_FIELD_STATUS) != BLOCK_JOB_STATUS_WAITING {
			return errors.New("Block Job is not in waiting state")
		}

		blockJob.Set(BLOCK_JOB_FIELD_STATUS, status)
		if jobErr != nil {
			var summary []string

			rawField := blockJob.Get(BLOCK_JOB_FIELD_SUMMARY).(types.JsonRaw)
			val, err := rawField.Value()
			if err != nil {
				return err
			}

			if val == nil {
				summary = []string{jobErr.Error()}
			} else {
				// TODO: There is a limit on the size of the summary field. We
				// should truncate it if it gets too big.
				err = blockJob.UnmarshalJSONField(BLOCK_JOB_FIELD_SUMMARY, &summary)
				if err != nil {
					return err
				}
				summary = append(summary, jobErr.Error())
			}

			blockJob.Set(BLOCK_JOB_FIELD_SUMMARY, summary)
			fmt.Println("summary", summary)
		}

		if err := txDao.SaveRecord(blockJob); err != nil {
			return err
		}
		return nil
	})
	return err
}

func (j *transJob) getFileInfo() (*FileInfo, error) {
	block, err := j.app.Dao().FindRecordById(COLLECTION_BLOCK, j.blockId)
	if err != nil {
		return nil, err
	}
	fileDir := path.Join(j.app.DataDir(), core.LocalStorageDirName, block.BaseFilesPath())
	fileName := block.GetString(BLOCK_FIELD_FILE)

	return &FileInfo{
		name:     fileName,
		dir:      fileDir,
		fullPath: path.Join(fileDir, fileName),
	}, nil
}

type ConvertedFileInfo struct {
	fullPath string
}

func (j *transJob) convertAudio(fileInfo *FileInfo) (*ConvertedFileInfo, error) {
	rootTempDir := filepath.Join(j.app.DataDir(), core.LocalTempDirName)
	if err := os.MkdirAll(rootTempDir, os.ModePerm); err != nil {
		return nil, err
	}
	// Ensure transcriptions subdir also exists
	convertedTempDir := filepath.Join(rootTempDir, tempTranscriptionDir)
	if err := os.MkdirAll(convertedTempDir, os.ModePerm); err != nil {
		return nil, err
	}

	convertedName := strings.TrimSuffix(fileInfo.name, filepath.Ext(fileInfo.name)) + "-converted.wav"
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

func (j *transJob) transcribe(convertedFileInfo ConvertedFileInfo) (*TranscriptionResult, error) {
	modelPath := path.Join(whisperModelsDir, whisperModelFilename)
	cmnd := exec.Command("whisper", "--prompt", transcriptionPrompt, "--model", modelPath, "-f", convertedFileInfo.fullPath, "--output-json")
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

func (j *transJob) saveTranscription(result *TranscriptionResult) error {
	err := j.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		blockRecord, err := txDao.FindRecordById(COLLECTION_BLOCK, j.blockId)
		if err != nil {
			return err
		}

		block, err := NewAudioBlock(blockRecord)
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
