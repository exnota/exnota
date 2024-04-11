package notion

import (
	"context"
	"errors"
	"log/slog"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/util"
	"exnota.com/backend/lib/pb_file"
	"github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"
)

type NotionWriter interface {
	CreateVoiceNotePage(request CreateVoiceNotePageRequest) (*notion.Page, error)
}

type notionWriter struct {
	app         core.App
	accessToken string
}

func NewNotionWriter(app core.App, accessToken string) NotionWriter {
	return &notionWriter{app, accessToken}
}

type CreateVoiceNotePageRequest struct {
	ParentType data.IntegrationNotionObjectType `validate:"required"`
	ParentID   string                           `validate:"required"`
	Files      []CreateVoiceNotePageRequestFile `validate:"required"`
}

type CreateVoiceNotePageRequestFile struct {
	Collection string `validate:"required"`
	RecordId   string `validate:"required"`
	FileName   string `validate:"required"`
}

func (n *notionWriter) CreateVoiceNotePage(
	request CreateVoiceNotePageRequest,
) (*notion.Page, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	client := notion.NewClient(n.accessToken)
	children := n.fileChildren(request.Files)

	switch request.ParentType {
	case data.IntegrationNotionObjectTypeDatabase:
		page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
			ParentType: notion.ParentTypeDatabase,
			ParentID:   request.ParentID,
			Title:      util.TextToRichText("dummy title db page"), // TODO: Remove
			Children:   children,
		})
		if err != nil {
			return nil, err
		}
		return &page, nil
	case data.IntegrationNotionObjectTypePage:
		title := util.TextToRichText("dummy title page") // TODO: Remove
		page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
			ParentType: notion.ParentTypePage,
			ParentID:   request.ParentID,
			Title:      title,
			Children:   children,
		})
		if err != nil {
			return nil, err
		}
		return &page, nil
	default:
		slog.Error("Unknown parent type", "type", request.ParentType)
		return nil, errors.New("unknown parent type")

	}
}

func (n *notionWriter) fileChildren(files []CreateVoiceNotePageRequestFile) []notion.Block {
	var children []notion.Block
	for _, file := range files {
		url := pb_file.Url(file.FileName, file.Collection, file.RecordId, n.app)
		block := notion.AudioBlock{
			Type: notion.FileTypeExternal,
			External: &notion.FileExternal{
				URL: url,
			},
			Caption: util.TextToRichText(file.FileName),
		}
		children = append(children, block)
	}
	return children
}
