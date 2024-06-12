package whisper

import (
	"os"
	"os/exec"
	"strconv"
)

type ModelPath string

const (
	ModelPathLargeV3        ModelPath = "/whisper/models/ggml-large-v3.bin"
	ModelPathWhisperLargeV2 ModelPath = "/whisper/models/ggml-large-v2.bin"
	ModelPathBase           ModelPath = "/whisper/models/ggml-base.bin"
)

// From https://platform.openai.com/docs/guides/speech-to-text/prompting
const prompt = "Hello, welcome to my lecture."

type WhisperCommand interface {
	Command(modelPath ModelPath, filePath string) *exec.Cmd
}

type whisperCommand struct {
	numThreads *int
}

func NewWhisperCommand(numThreads *int) WhisperCommand {
	return &whisperCommand{numThreads: numThreads}
}

func (w *whisperCommand) Command(modelPath ModelPath, filePath string) *exec.Cmd {
	cmdArgs := []string{
		"whisper",
		"--prompt",
		prompt,
		"-f",
		filePath,
		"--output-json",
	}

	// Threads
	if w.numThreads != nil {
		cmdArgs = append(cmdArgs, "-t", strconv.Itoa(*w.numThreads))
	}

	// Model
	// Use base path if model path is not found. E.g. to speed up local build
	// or testing.
	if _, err := os.Stat(string(modelPath)); err != nil {
		modelPath = ModelPathBase
	}

	cmdArgs = append(cmdArgs, "--model", string(modelPath))

	return exec.Command(cmdArgs[0], cmdArgs[1:]...)
}
