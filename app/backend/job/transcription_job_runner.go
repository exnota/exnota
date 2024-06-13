package job

import (
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"exnota.com/backend/block"
	"exnota.com/backend/job/data"
	"exnota.com/backend/lib/account"
	lib_block "exnota.com/backend/lib/block"
	"exnota.com/backend/lib/pb_file"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

const tempTranscriptionDir = "transcription"

type TranscriptionJobRunner interface {
	RunnableBlockJob
}

type transcriptionJobRunner struct {
	app                core.App
	whisperV3Generator lib_block.TranscriptionGenerator
	whisperV2Generator lib_block.TranscriptionGenerator
	openAIGenerator    lib_block.TranscriptionGenerator
	getFeatureSettings account.GetFeatureSettings
	blockFetcher       block.BlockFetcher
}

func NewTranscriptionJobRunner(
	app core.App,
	whisperV3Generator lib_block.TranscriptionGenerator,
	whisperV2Generator lib_block.TranscriptionGenerator,
	openAIGenerator lib_block.TranscriptionGenerator,
	getFeatureSettings account.GetFeatureSettings,
	blockFetcher block.BlockFetcher,
) TranscriptionJobRunner {
	return &transcriptionJobRunner{
		app,
		whisperV3Generator,
		whisperV2Generator,
		openAIGenerator,
		getFeatureSettings,
		blockFetcher,
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

	err = j.transcribe(*convertedFileInfo, job.User(), job.Block())
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

func (j *transcriptionJobRunner) transcribe(
	convertedFileInfo ConvertedFileInfo,
	user string,
	blockId string,
) error {
	// Get service settings
	settings, err := j.getFeatureSettings.GetExnotaSettings(
		account.ExnotaFeatureVoiceNoteNameID, user,
	)
	if err != nil {
		return err
	}
	voiceNoteSettings, ok := settings.(account.VoiceNoteSettings)
	if !ok {
		return fmt.Errorf("incorrect type for voiceNoteSettings")
	}

	// Transcribe
	var paragraphs []string
	switch voiceNoteSettings.Service {
	case account.VoiceNoteServiceWhisperLargeV3:
		paragraphs, err = j.whisperV3Generator.Generate(convertedFileInfo.fullPath)
		if err != nil {
			slog.Error("Error generating transcription for whisper large v3", "error", err)
			return fmt.Errorf("error generating transcription for whisper large v3: %w", err)
		}
	case account.VoiceNoteServiceWhisperLargeV2:
		paragraphs, err = j.whisperV2Generator.Generate(convertedFileInfo.fullPath)
		if err != nil {
			slog.Error("Error generating transcription for whisper large v2", "error", err)
			return fmt.Errorf("error generating transcription for whisper large v2: %w", err)
		}
	case account.VoiceNoteServiceOpenAI:
		paragraphs, err = j.openAIGenerator.Generate(convertedFileInfo.fullPath)
		if err != nil {
			slog.Error("Error generating transcription for openai", "error", err)
			return fmt.Errorf("error generating transcription for openai: %w", err)
		}
	default:
		panic(fmt.Sprintf("unsupported voice note service: %s", string(voiceNoteSettings.Service)))
	}

	// Persist
	err = j.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		b, err := j.blockFetcher.FetchVoiceNoteByIdInTx(txDao, blockId)
		if err != nil {
			return err
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
