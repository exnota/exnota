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
)

const tempTranscriptionDir = "transcription"

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

	err = j.convertAudio(fileInfo)
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
			summaryJson := blockJob.Get(BLOCK_JOB_FIELD_SUMMARY)
			var summary []string
			if summaryJson == nil {
				summary = []string{jobErr.Error()}
			} else {
				err = json.Unmarshal([]byte(summaryJson.(string)), &summary)
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

func (j *transJob) convertAudio(fileInfo *FileInfo) error {
	rootTempDir := filepath.Join(j.app.DataDir(), core.LocalTempDirName)
	if err := os.MkdirAll(rootTempDir, os.ModePerm); err != nil {
		return err
	}
	// Ensure transcriptions subdir also exists
	convertedTempDir := filepath.Join(rootTempDir, tempTranscriptionDir)
	if err := os.MkdirAll(convertedTempDir, os.ModePerm); err != nil {
		return err
	}

	convertedName := strings.TrimSuffix(fileInfo.name, filepath.Ext(fileInfo.name)) + "-converted.wav"
	convertedPath := path.Join(convertedTempDir, convertedName)
	fmt.Println("convertedPath", convertedPath)

	cmnd := exec.Command("ffmpeg", "-i", fileInfo.fullPath,
		"-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", convertedPath)
	out, err := cmnd.CombinedOutput()
	fmt.Println("Audio file conversion:")
	fmt.Println(string(out))
	if err != nil {
		return err
	}
	return nil
}
