package integration

import "errors"

// General errors
var ErrInvalidToken = errors.New("invalid token")

// Integration-specific errors.
//
// These are passed from the third-party layer to the general integration layer,
// which converts them to the general error.
var ErrNotionInvalidToken = errors.New("invalid Notion token")

func ToIntegrationError(err error) error {
	if errors.Is(err, ErrNotionInvalidToken) {
		return ErrInvalidToken
	}

	return err
}
