package api

import (
	"context"
	"errors"
	"log/slog"

	gonotion "github.com/dstotijn/go-notion"
)

type NotionFetcher interface {
	FetchPage(pageID string) (*gonotion.Page, error)
	FetchPageChildren(pageID string) ([]gonotion.Block, error)
	FetchPageChildrenWithAccessToken(pageID string) ([]gonotion.Block, error)
	FetchDatabase(databaseID string) (*gonotion.Database, error) // Added method

	// Returns `true` if access token is still valid, `false` if not, or an
	// an error if verification couldn't be attempted.
	VerifyAccess() (bool, error)
}

type notionFetcher struct {
	accessToken string
}

func NewNotionFetcher(accessToken string) NotionFetcher {
	return &notionFetcher{accessToken}
}

func (f *notionFetcher) FetchPage(pageID string) (*gonotion.Page, error) {
	client := gonotion.NewClient(f.accessToken)
	result, err := client.FindPageByID(context.Background(), pageID)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

func (f *notionFetcher) FetchPageChildren(
	pageID string,
) ([]gonotion.Block, error) {
	client := gonotion.NewClient(f.accessToken)
	result, err := client.FindBlockChildrenByID(context.Background(), pageID, nil)
	if err != nil {
		return nil, err
	}

	return result.Results, nil
}

func (f *notionFetcher) FetchPageChildrenWithAccessToken(
	pageID string,
) ([]gonotion.Block, error) {
	client := gonotion.NewClient(f.accessToken)
	result, err := client.FindBlockChildrenByID(context.Background(), pageID, nil)
	if err != nil {
		return nil, err
	}

	return result.Results, nil
}

func (f *notionFetcher) FetchDatabase(
	databaseID string,
) (*gonotion.Database, error) {
	client := gonotion.NewClient(f.accessToken)
	result, err := client.FindDatabaseByID(context.Background(), databaseID)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

func (f *notionFetcher) VerifyAccess() (bool, error) {
	client := gonotion.NewClient(f.accessToken)
	opts := &gonotion.SearchOpts{
		Query:    "",
		PageSize: 1,
	}

	// The Notion API returns the same error whether the user revokes access in
	// Notion > Settings > My connections, or if the token is modified. This can
	// be useful for testing, as we can append a character to the token to
	// simulate a revoked token.
	//
	// If the user removes all shared pages/databases, no error will be returned
	// from the Notion API. It will just return an empty list of results.
	_, err := client.Search(context.Background(), opts)
	if err != nil {
		if errors.Unwrap(errors.Unwrap(err)) == gonotion.ErrUnauthorized {
			slog.Info("Unauthorized")
			return false, nil
		}
		slog.Error("Error doing verify search of notion", "err", err)
		return false, nil
	}
	return true, nil
}
