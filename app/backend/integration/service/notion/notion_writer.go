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

type UpdatePageRequest struct {
	PageId             string `validate:"required"`
	DatabaseProperties gonotion.DatabasePageProperties
	Children           []gonotion.Block `validate:"required"`
	AfterId            *string
}

type NotionWriter interface {
	CreateDatabasePage(request CreateDatabasePageRequest) (*CreateDatabasePageResponse, error)
	CreateChildPage(request CreateChildPageRequest) (*CreateChildPageResponse, error)
	UpdatePage(request UpdatePageRequest) (*UpdatePageResponse, error)
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
	Url      string
}

type CreateChildPageResponse struct {
	// New page ID
	PageId string
	// Ids of inserted child blocks
	Children []string
	// Page URL in Notion
	Url string
}

type UpdatePageResponse struct {
	// Ids of inserted child blocks
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
		Children:               request.Children,
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
	notionFetcher := NewNotionFetcher(n.app)
	children, err := notionFetcher.FetchPageChildren(pageId, n.accessToken)
	if err != nil {
		slog.Error(
			"Failed to fetch page children. Swallowing error as the job shouldn't be retried just because we're missing mappings.",
			"error",
			err,
		)
		children = []notion.Block{}
	}

	var childIDs []string
	for _, child := range children {
		childIDs = append(childIDs, child.ID())
	}

	return &CreateDatabasePageResponse{
		PageId:   pageId,
		Children: childIDs,
		Url:      page.URL,
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
		Children:   request.Children,
	})
	if err != nil {
		return nil, err
	}

	pageId := page.ID
	notionFetcher := NewNotionFetcher(n.app)
	children, err := notionFetcher.FetchPageChildren(pageId, n.accessToken)
	if err != nil {
		slog.Error(
			"Failed to fetch page children. Swallowing error as the job shouldn't be retried just because we're missing mappings.",
			"error",
			err,
		)
		children = []notion.Block{}
	}

	var childIDs []string
	for _, child := range children {
		childIDs = append(childIDs, child.ID())
	}

	return &CreateChildPageResponse{
		PageId:   pageId,
		Children: childIDs,
		Url:      page.URL,
	}, nil
}

func (n *notionWriter) UpdatePage(
	request UpdatePageRequest,
) (*UpdatePageResponse, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	// Update page properties
	if len(request.DatabaseProperties) > 0 {
		client := notion.NewClient(n.accessToken)
		_, err = client.UpdatePage(context.Background(), request.PageId, gonotion.UpdatePageParams{
			// Title of child pages are updated using the "title" property, despite
			// the struct property name here being 'database page properties'.
			DatabasePageProperties: request.DatabaseProperties,
		})
		if err != nil {
			return nil, err
		}
	}

	// Append children
	var childIDs []string
	if len(request.Children) > 0 {
		extendedClient := NewExtendedClient(n.accessToken)
		childrenResp, err := extendedClient.AppendBlockChildren(
			context.Background(),
			request.PageId,
			request.Children,
			request.AfterId,
		)
		if err != nil {
			slog.Error("Failed to append block children", "error", err)
			return nil, err
		}

		for _, child := range childrenResp.Results {
			childIDs = append(childIDs, child.ID())
		}
	}

	return &UpdatePageResponse{
		Children: childIDs,
	}, nil
}
