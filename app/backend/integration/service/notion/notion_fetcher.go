package notion

import (
	"context"

	"exnota.com/backend/integration/data"
	"github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"
)

type NotionFetcher interface {
	FetchPage(pageID string, integrationID string) (*notion.Page, error)
	FetchPageChildren(pageID string, integrationID string) ([]notion.Block, error)
	FetchPageChildrenWithAccessToken(pageID string, accessToken string) ([]notion.Block, error)
	FetchDatabase(databaseID string, integrationID string) (*notion.Database, error) // Added method
}

type notionFetcher struct {
	app core.App
}

func NewNotionFetcher(app core.App) NotionFetcher {
	return &notionFetcher{app}
}

func (f *notionFetcher) FetchPage(pageID string, integrationID string) (*notion.Page, error) {
	accessToken, err := f.accessToken(integrationID)
	if err != nil {
		return nil, err
	}

	client := notion.NewClient(accessToken)
	result, err := client.FindPageByID(context.Background(), pageID)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

func (f *notionFetcher) FetchPageChildren(
	pageID string,
	integrationID string,
) ([]notion.Block, error) {
	accessToken, err := f.accessToken(integrationID)
	if err != nil {
		return nil, err
	}

	client := notion.NewClient(accessToken)
	result, err := client.FindBlockChildrenByID(context.Background(), pageID, nil)
	if err != nil {
		return nil, err
	}

	return result.Results, nil
}

func (f *notionFetcher) FetchPageChildrenWithAccessToken(
	pageID string,
	accessToken string,
) ([]notion.Block, error) {
	client := notion.NewClient(accessToken)
	result, err := client.FindBlockChildrenByID(context.Background(), pageID, nil)
	if err != nil {
		return nil, err
	}

	return result.Results, nil
}

func (f *notionFetcher) FetchDatabase(
	databaseID string,
	integrationID string,
) (*notion.Database, error) {
	accessToken, err := f.accessToken(integrationID)
	if err != nil {
		return nil, err
	}

	client := notion.NewClient(accessToken)
	result, err := client.FindDatabaseByID(context.Background(), databaseID)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

func (f *notionFetcher) accessToken(integrationID string) (string, error) {
	integrationFetcher := data.NewIntegrationFetcher(f.app)
	integration, err := integrationFetcher.FetchNotionIntegration(integrationID)
	if err != nil {
		return "", err
	}

	config, err := integration.Config()
	if err != nil {
		return "", err
	}
	return *config.Auth.AccessToken, nil
}
