package notion

import (
	"context"
	"errors"
	"log/slog"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/util"
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
	Path string
	Name string
}

func (n *notionWriter) CreateVoiceNotePage(request CreateVoiceNotePageRequest) (*notion.Page, error) {
	client := notion.NewClient(n.accessToken)

	switch request.ParentType {
	case data.IntegrationNotionObjectTypeDatabase:
		page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
			ParentType: notion.ParentTypeDatabase,
			ParentID:   request.ParentID,
			Title:      util.TextToTitle("dummy title db page"), // TODO: Remove
		})
		if err != nil {
			return nil, err
		}
		return &page, nil
	case data.IntegrationNotionObjectTypePage:
		title := util.TextToTitle("dummy title page") // TODO: Remove
		page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
			ParentType: notion.ParentTypePage,
			ParentID:   request.ParentID,
			Title:      title,
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
