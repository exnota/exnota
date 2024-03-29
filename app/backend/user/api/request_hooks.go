package requesthooks

import (
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type UserRequestHooks interface {
	Apply()
}

type userRequestHooks struct {
	app core.App
}

func NewUserRequestHooks(app core.App) UserRequestHooks {
	return &userRequestHooks{app: app}
}

func (h *userRequestHooks) Apply() {
	h.app.OnRecordsListRequest().Add(func(e *core.RecordsListEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}

		if requestInfo.AuthRecord == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}

		if !requestInfo.AuthRecord.Verified() {
			return apis.NewUnauthorizedError("Not verified", nil)
		}

		return nil
	})

	h.app.OnRecordViewRequest().Add(func(e *core.RecordViewEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}

		if requestInfo.AuthRecord == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}

		if !requestInfo.AuthRecord.Verified() {
			return apis.NewUnauthorizedError("Not verified", nil)
		}

		return nil
	})

	h.app.OnRecordBeforeCreateRequest().Add(func(e *core.RecordCreateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}

		if requestInfo.AuthRecord == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}

		if !requestInfo.AuthRecord.Verified() {
			return apis.NewUnauthorizedError("Not verified", nil)
		}

		return nil
	})

	h.app.OnRecordBeforeUpdateRequest().Add(func(e *core.RecordUpdateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}

		if requestInfo.AuthRecord == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}

		if !requestInfo.AuthRecord.Verified() {
			return apis.NewUnauthorizedError("Not verified", nil)
		}

		return nil
	})

	h.app.OnRecordBeforeDeleteRequest().Add(func(e *core.RecordDeleteEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.Admin != nil {
			return nil
		}

		if requestInfo.AuthRecord == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}

		if !requestInfo.AuthRecord.Verified() {
			return apis.NewUnauthorizedError("Not verified", nil)
		}

		return nil
	})
}
