package job

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	whisper "exnota.com/backend/lib"
	"exnota.com/backend/record"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/tools/types"
)

const tempTranscriptionDir = "transcription"

type TranscriptionJobRunner interface {
	Run() error
}

type transcriptionJobRunner struct {
	blockJobId string
	blockId    string
	app        core.App
}

func NewTranscriptionJobRunner(blockJobId string, blockId string, app core.App) TranscriptionJobRunner {
	return &transcriptionJobRunner{
		blockJobId: blockJobId,
		blockId:    blockId,
		app:        app,
	}
}

// run method
func (j *transcriptionJobRunner) Run() error {
	err := j.setJobStatus("running", true, nil)
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

	err = j.setJobStatus("complete", false, nil)
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

func (j *transcriptionJobRunner) setJobStatusError(jobErr error) error {
	return j.setJobStatus("error", false, jobErr)
}

func (j *transcriptionJobRunner) setJobStatus(status string, validateWaiting bool, jobErr error) error {
	err := j.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		blockJob, err := txDao.FindRecordById("block_job", j.blockJobId)
		if err != nil {
			return err
		}

		if validateWaiting && blockJob.GetString("status") != "waiting" {
			return errors.New("Block Job is not in waiting state")
		}

		blockJob.Set("status", status)
		if jobErr != nil {
			var summary []string

			rawField := blockJob.Get("summary").(types.JsonRaw)
			val, err := rawField.Value()
			if err != nil {
				return err
			}

			if val == nil {
				summary = []string{jobErr.Error()}
			} else {
				// TODO: There is a limit on the size of the summary field. We
				// should truncate it if it gets too big.
				err = blockJob.UnmarshalJSONField("summary", &summary)
				if err != nil {
					return err
				}
				summary = append(summary, jobErr.Error())
			}

			blockJob.Set("summary", summary)
			fmt.Println("summary", summary)
		}

		if err := txDao.SaveRecord(blockJob); err != nil {
			return err
		}
		return nil
	})
	return err
}

func (j *transcriptionJobRunner) getFileInfo() (*FileInfo, error) {
	block, err := j.app.Dao().FindRecordById("block", j.blockId)
	if err != nil {
		return nil, err
	}
	fileDir := path.Join(j.app.DataDir(), core.LocalStorageDirName, block.BaseFilesPath())
	fileName := block.GetString("file")

	return &FileInfo{
		name:     fileName,
		dir:      fileDir,
		fullPath: path.Join(fileDir, fileName),
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

func (j *transcriptionJobRunner) transcribe(convertedFileInfo ConvertedFileInfo) (*TranscriptionResult, error) {
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

func (j *transcriptionJobRunner) saveTranscription(result *TranscriptionResult) error {
	err := j.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		blockRecord, err := txDao.FindRecordById("block", j.blockId)
		if err != nil {
			return err
		}

		block, err := record.NewAudioBlock(blockRecord)
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
