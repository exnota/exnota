package block

type TranscriptionGenerator interface {
	// Returns paragraphs.
	Generate(fullPath string) ([]string, error)
}
