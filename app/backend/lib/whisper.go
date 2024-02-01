package whisper

import (
	"os"
	"os/exec"
)

const largeModelPath = "/whisper/models/ggml-large-v3.bin"
const baseModelPath = "/whisper/models/ggml-base.bin"

// From https://platform.openai.com/docs/guides/speech-to-text/prompting
const prompt = "Hello, welcome to my lecture."

func Command(filePath string) *exec.Cmd {
	if _, err := os.Stat(largeModelPath); err == nil {
		return exec.Command("whisper", "--prompt", prompt, "--model", largeModelPath, "-f", filePath, "--output-json")

	} else {
		return exec.Command("whisper", "--prompt", prompt, "--model", baseModelPath, "-f", filePath, "--output-json")
	}
}
