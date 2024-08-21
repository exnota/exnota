package api

import (
	"net/http"

	validation "github.com/go-ozzo/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase/apis"
)

func NewMethodNotAllowedError(message string, data any) *apis.ApiError {
	if message == "" {
		message = "This method is not allowed"
	}

	return apis.NewApiError(http.StatusMethodNotAllowed, message, data)
}

func NewBadRequestWithErrorCode(errorCode string, message string) *apis.ApiError {
	// "ApiError.RawData() will be returned in the response only if it is a map
	// of validation.Error items."
	//
	// https://pocketbase.io/docs/go-routing#error-response
	return apis.NewBadRequestError(message, map[string]validation.Error{
		"errorCode": validation.NewError(errorCode, message),
	})
}
