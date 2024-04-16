package notion

import (
	"context"
	"log/slog"

	"exnota.com/backend/integration/util"
	"github.com/dstotijn/go-notion"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"
)

type CreateDatabasePageRequest struct {
	DatabaseId         string `validate:"required"`
	DatabaseProperties *gonotion.DatabasePageProperties
	Children           []gonotion.Block
}

type CreateChildPageRequest struct {
	ParentId string `validate:"required"`
	Title    []gonotion.RichText
	Children []gonotion.Block
}

type NotionWriter interface {
	CreateDatabasePage(request CreateDatabasePageRequest) (*CreateDatabasePageResponse, error)
	CreateChildPage(request CreateChildPageRequest) (*CreateChildPageResponse, error)
}

type notionWriter struct {
	app         core.App
	accessToken string
}

func NewNotionWriter(app core.App, accessToken string) NotionWriter {
	return &notionWriter{app, accessToken}
}

type CreateDatabasePageResponse struct {
	PageId   string
	Children []string
}

type CreateChildPageResponse struct {
	PageId   string
	Children []string
}

func (n *notionWriter) CreateDatabasePage(
	request CreateDatabasePageRequest,
) (*CreateDatabasePageResponse, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	client := notion.NewClient(n.accessToken)

	properties := request.DatabaseProperties
	if properties == nil {
		// go-notion requires an empty struct
		properties = &gonotion.DatabasePageProperties{}
	}
	page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
		ParentType:             notion.ParentTypeDatabase,
		ParentID:               request.DatabaseId,
		DatabasePageProperties: properties,
		// DatabasePageProperties: &notion.DatabasePageProperties{
		// 	"Name": notion.DatabasePageProperty{
		// 		Type: notion.DBPropTypeTitle,
		// 		ID:   "title",
		// 		Title: []notion.RichText{
		// 			{
		// 				Text: &notion.Text{
		// 					Content: "dummy title db page xy", // TODO: Remove
		// 				},
		// 			},
		// 		},
		// 	},
		// },
	})
	if err != nil {
		return nil, err
	}

	pageId := page.ID
	children, err := client.AppendBlockChildren(context.Background(), pageId, request.Children)
	if err != nil {
		slog.Error("Failed to append block children", "error", err)
		return nil, err
	}

	var childIDs []string
	for _, child := range children.Results {
		childIDs = append(childIDs, child.ID())
	}

	return &CreateDatabasePageResponse{
		PageId:   pageId,
		Children: childIDs,
	}, nil
}

func (n *notionWriter) CreateChildPage(
	request CreateChildPageRequest,
) (*CreateChildPageResponse, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	client := notion.NewClient(n.accessToken)

	title := util.TextToRichText("dummy title page") // TODO: Remove
	page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
		ParentType: notion.ParentTypePage,
		ParentID:   request.ParentId,
		Title:      title,
	})
	if err != nil {
		return nil, err
	}

	pageId := page.ID
	children, err := client.AppendBlockChildren(context.Background(), pageId, request.Children)
	if err != nil {
		slog.Error("Failed to append block children", "error", err)
		return nil, err
	}

	var childIDs []string
	for _, child := range children.Results {
		childIDs = append(childIDs, child.ID())
	}

	return &CreateChildPageResponse{
		PageId:   pageId,
		Children: childIDs,
	}, nil
}
