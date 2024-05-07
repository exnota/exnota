package api

import (
	"exnota.com/backend/block"
	validation "github.com/go-ozzo/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms/validators"
)

type BlockCreateAPI interface {
	ApplyHooks()
}

type blockCreateAPI struct {
	app core.App
}

func NewBlockCreateAPI(app core.App) BlockCreateAPI {
	return &blockCreateAPI{
		app: app,
	}
}

func (h *blockCreateAPI) ApplyHooks() {
	// voice note must have a file
	h.app.OnRecordBeforeCreateRequest(block.CollectionBlock).
		Add(func(e *core.RecordCreateEvent) error {
			b, err := block.LoadBlock(e.Record, h.app)
			if err != nil {
				return err
			}

			// voice note must have a file
			if b.Type() == block.BlockTypeVoiceNote {
				files := e.UploadedFiles[block.BlockFieldFile]
				if len(files) != 1 {
					return apis.NewBadRequestError("Voice note block must have exactly 1 file", nil)
				}

				// Content types supported by Pocketbase: https://github.com/gabriel-vasile/mimetype/blob/master/supported_mimes.md
				// The mime type *may* also be in the attributes returned by filesystem.Attributes(): https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/tools/filesystem/filesystem.go#L104
				if err := validators.UploadedFileMimeType([]string{"audio/wav", "audio/mpeg"})(files[0]); err != nil {
					// Verify it's a mime type error, because if we simply return
					// the err object the error message will be a generic
					// "Something went wrong while processing your request."
					errObj := err.(validation.ErrorObject)
					if errObj.Code() == "validation_invalid_mime_type" {
						return apis.NewBadRequestError(
							"Voice note block must have a .wav or .mp3 file.",
							nil,
						)
					}
					return err
				}
			} else {
				files := e.UploadedFiles[block.BlockFieldFile]
				if len(files) != 0 {
					return apis.NewBadRequestError("Non-voice note block cannot have a file", nil)
				}
			}

			return nil
		})
}
