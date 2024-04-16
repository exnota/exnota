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

// TODO: Use some consistent properties across requests. For thoughts on a
// properties field, check the essay in block_job.go
type CreateVoiceNotePageRequest struct {
	Parent data.IntegrationNotionObject
	Files  []CreateVoiceNotePageRequestFile `validate:"required"`
}

type CreateVoiceNotePageRequestFile struct {
	Collection string `validate:"required"`
	BlockId    string `validate:"required"`
	FileName   string `validate:"required"`
	FilePath   string `validate:"required"`
	Url        string `validate:"required"`
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

	switch request.Parent.Type() {
	case data.IntegrationNotionObjectTypeDatabase:
		titlePropId, err := request.Parent.DatabaseTitlePropertyId()
		if err != nil {
			return nil, err
		}

		page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
			ParentType: notion.ParentTypeDatabase,
			ParentID:   request.Parent.ExternalId(),
			Children:   children,
			DatabasePageProperties: &notion.DatabasePageProperties{
				titlePropId: notion.DatabasePageProperty{
					Type: notion.DBPropTypeTitle,
					ID:   titlePropId,
					Title: []notion.RichText{
						{
							Text: &notion.Text{
								Content: "dummy title db page x", // TODO: Remove
							},
						},
					},
				},
			},
		})
		if err != nil {
			return nil, err
		}
		return &page, nil
	case data.IntegrationNotionObjectTypePage:
		title := util.TextToRichText("dummy title page") // TODO: Remove
		page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
			ParentType: notion.ParentTypePage,
			ParentID:   request.Parent.ExternalId(),
			Title:      title,
			Children:   children,
		})
		if err != nil {
			return nil, err
		}
		return &page, nil
	default:
		slog.Error("Unknown parent type", "type", request.Parent.Type())
		return nil, errors.New("unknown parent type")
	}
}

func (n *notionWriter) fileChildren(files []CreateVoiceNotePageRequestFile) []notion.Block {
	var children []notion.Block
	for _, file := range files {
		block := notion.AudioBlock{
			Type: notion.FileTypeExternal,
			External: &notion.FileExternal{
				URL: file.Url,
			},
			Caption: util.TextToRichText(file.FileName),
		}
		children = append(children, block)
	}
	return children
}
