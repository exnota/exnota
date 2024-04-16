package util

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"log/slog"
	"os"
)

func ContentHash(input string) string {
	hash := sha256.Sum256([]byte(input))
	return hex.EncodeToString(hash[:])
}

func FileContentHash(filePath string) (string, error) {
	f, err := os.Open(filePath)
	if err != nil {
		slog.Error("Error opening file", "filePath", filePath, "err", err)
		return "", err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		slog.Error("Error copying file content", "filePath", filePath, "err", err)
		return "", err
	}
	hash := string(h.Sum(nil))
	return hash, nil
}
