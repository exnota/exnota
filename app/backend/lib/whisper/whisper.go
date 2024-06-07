package whisper

import (
	"os"
	"os/exec"
	"strconv"
)

const largeModelPath = "/whisper/models/ggml-large-v3.bin"
const baseModelPath = "/whisper/models/ggml-base.bin"

// From https://platform.openai.com/docs/guides/speech-to-text/prompting
const prompt = "Hello, welcome to my lecture."

type Whisper interface {
	Command(filePath string) *exec.Cmd
}

type whisper struct {
	numThreads *int
}

func NewWhisper(numThreads *int) Whisper {
	return &whisper{numThreads: numThreads}
}

func (w *whisper) Command(filePath string) *exec.Cmd {

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
	modelPath := baseModelPath
	// Use the large model if it exists
	if _, err := os.Stat(largeModelPath); err == nil {
		modelPath = largeModelPath
	}

	cmdArgs = append(cmdArgs, "--model", modelPath)

	return exec.Command(cmdArgs[0], cmdArgs[1:]...)
}
