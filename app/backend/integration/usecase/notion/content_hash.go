package notion

import "exnota.com/backend/integration/util"

type TitleContentHashInput struct {
	Title string `validate:"min=1"`
}

func BlockTitleToContentHash(input TitleContentHashInput) (string, error) {
	err := validate.Struct(input)
	if err != nil {
		return "", err
	}

	return util.ContentHash(input.Title), nil
}

type FileContentHashInput struct {
	Collection string `validate:"min=1"`
	RecordId   string `validate:"min=1"`
	Filename   string `validate:"min=1"`
}

func BlockFileToContentHash(input FileContentHashInput) (string, error) {
	err := validate.Struct(input)
	if err != nil {
		return "", err
	}

	return util.ContentHash(input.Collection + input.RecordId + input.Filename), nil
}
