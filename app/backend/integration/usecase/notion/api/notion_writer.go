package api

import (
	"context"
	"errors"
	"log/slog"

	"github.com/dstotijn/go-notion"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"

	lib_integ "exnota.com/backend/lib/integration"
)

type NotionWriter interface {
	CreateDatabasePage(request CreateDatabasePageRequest) (*CreateDatabasePageResponse, error)
	CreateChildPage(request CreateChildPageRequest) (*CreateChildPageResponse, error)
	UpdatePageProperties(request UpdatePagePropertiesRequest) error
	AppendPageChildren(request AppendPageChildrenRequest) (*AppendPageChildrenResponse, error)
}

type notionWriter struct {
	app         core.App
	accessToken string
}

func NewNotionWriter(app core.App, accessToken string) NotionWriter {
	return &notionWriter{app, accessToken}
}

type CreateDatabasePageRequest struct {
	DatabaseId         string `validate:"required"`
	DatabaseProperties *gonotion.DatabasePageProperties
	Children           []gonotion.Block
}

type CreateDatabasePageResponse struct {
	PageId   string
	Children []string
	Url      string
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
		ParentType: notion.ParentTypeDatabase,
		ParentID:   request.DatabaseId,
		// DatabasePageProperties must be non-nil for go-notion to detect this
		// as creating a database page instead of a child page.
		//
		// Conversely, don't provide 'Title' as go-notion may interpret this
		// as a child page instead of a database page.
		DatabasePageProperties: properties,
		Children:               request.Children,
	})
	if err != nil {
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
		return nil, err
	}

	pageId := page.ID
	notionFetcher := NewNotionFetcher(n.accessToken)
	children, err := notionFetcher.FetchPageChildrenWithAccessToken(pageId)
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

type CreateChildPageRequest struct {
	ParentId string `validate:"required"`
	// Title must be non-nil for go-notion to detect this as creating a
	// child page instead of a database page.
	//
	// Conversely, don't provide 'DatabasePageProperties' as go-notion may
	// interpret this as a database page instead of a child page.
	Title    []gonotion.RichText `validate:"required"`
	Children []gonotion.Block
}
type CreateChildPageResponse struct {
	// New page ID
	PageId string
	// Ids of inserted child blocks
	Children []string
	// Page URL in Notion
	Url string
}

func (n *notionWriter) CreateChildPage(
	request CreateChildPageRequest,
) (*CreateChildPageResponse, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
	}

	client := notion.NewClient(n.accessToken)

	page, err := client.CreatePage(context.Background(), notion.CreatePageParams{
		ParentType: notion.ParentTypePage,
		ParentID:   request.ParentId,
		// Title must be non-nil for go-notion to detect this as creating a
		// child page instead of a database page.
		Title:    request.Title,
		Children: request.Children,
	})
	if err != nil {
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
		return nil, err
	}

	pageId := page.ID
	notionFetcher := NewNotionFetcher(n.accessToken)
	children, err := notionFetcher.FetchPageChildren(pageId)
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

type UpdatePagePropertiesRequest struct {
	PageId             string `validate:"required"`
	DatabaseProperties gonotion.DatabasePageProperties
}

func (n *notionWriter) UpdatePageProperties(
	request UpdatePagePropertiesRequest,
) error {
	err := validate.Struct(request)
	if err != nil {
		return err
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
			if errors.Is(err, gonotion.ErrUnauthorized) {
				return lib_integ.ErrNotionInvalidToken
			}
			return err
		}
	}

	return nil
}

type AppendPageChildrenRequest struct {
	PageId   string           `validate:"required"`
	Children []gonotion.Block `validate:"required"`
	AfterId  *string
}

type AppendPageChildrenResponse struct {
	// Ids of inserted child blocks
	Children []string
}

func (n *notionWriter) AppendPageChildren(
	request AppendPageChildrenRequest,
) (*AppendPageChildrenResponse, error) {
	err := validate.Struct(request)
	if err != nil {
		return nil, err
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
			if errors.Is(err, gonotion.ErrUnauthorized) {
				return nil, lib_integ.ErrNotionInvalidToken
			}
			return nil, err
		}

		for _, child := range childrenResp.Results {
			childIDs = append(childIDs, child.ID())
		}
	}

	return &AppendPageChildrenResponse{
		Children: childIDs,
	}, nil
}
