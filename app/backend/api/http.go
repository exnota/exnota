package api

import (
	"net/http"

	"github.com/pocketbase/pocketbase/apis"
)

func NewMethodNotAllowedError(message string, data any) *apis.ApiError {
	if message == "" {
		message = "This method is not allowed"
	}

	return apis.NewApiError(http.StatusMethodNotAllowed, message, data)
}
