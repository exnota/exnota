package api

import (
	"context"

	"github.com/dstotijn/go-notion"
)

type NotionFetcher interface {
	FetchPage(pageID string) (*notion.Page, error)
	FetchPageChildren(pageID string) ([]notion.Block, error)
	FetchPageChildrenWithAccessToken(pageID string) ([]notion.Block, error)
	FetchDatabase(databaseID string) (*notion.Database, error) // Added method
}

type notionFetcher struct {
	accessToken string
}

func NewNotionFetcher(accessToken string) NotionFetcher {
	return &notionFetcher{accessToken}
}

func (f *notionFetcher) FetchPage(pageID string) (*notion.Page, error) {
	client := notion.NewClient(f.accessToken)
	result, err := client.FindPageByID(context.Background(), pageID)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

func (f *notionFetcher) FetchPageChildren(
	pageID string,
) ([]notion.Block, error) {
	client := notion.NewClient(f.accessToken)
	result, err := client.FindBlockChildrenByID(context.Background(), pageID, nil)
	if err != nil {
		return nil, err
	}

	return result.Results, nil
}

func (f *notionFetcher) FetchPageChildrenWithAccessToken(
	pageID string,
) ([]notion.Block, error) {
	client := notion.NewClient(f.accessToken)
	result, err := client.FindBlockChildrenByID(context.Background(), pageID, nil)
	if err != nil {
		return nil, err
	}

	return result.Results, nil
}

func (f *notionFetcher) FetchDatabase(
	databaseID string,
) (*notion.Database, error) {
	client := notion.NewClient(f.accessToken)
	result, err := client.FindDatabaseByID(context.Background(), databaseID)
	if err != nil {
		return nil, err
	}

	return &result, nil
}
