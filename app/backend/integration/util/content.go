package util

import (
	"crypto/sha256"
	"encoding/hex"
)

func ContentHash(input string) string {
	hash := sha256.Sum256([]byte(input))
	return hex.EncodeToString(hash[:])
}
