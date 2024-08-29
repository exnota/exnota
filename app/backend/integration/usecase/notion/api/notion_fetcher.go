package api

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	gonotion "github.com/dstotijn/go-notion"

	lib_integ "exnota.com/backend/lib/integration"
)

type NotionFetcher interface {
	FetchPage(pageID string) (*gonotion.Page, error)
	FetchPageChildren(pageID string) ([]gonotion.Block, error)
	FetchPageChildrenWithAccessToken(pageID string) ([]gonotion.Block, error)
	FetchDatabase(databaseID string) (*gonotion.Database, error) // Added method

	Search(pageID string) (gonotion.SearchResults, error)
	SearchDatabases(query string) ([]gonotion.Database, error)
	SearchPages(query string) ([]gonotion.Page, error)

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
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
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
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
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
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
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
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
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

func (f *notionFetcher) Search(query string) (gonotion.SearchResults, error) {
	client := gonotion.NewClient(f.accessToken)
	opts := &gonotion.SearchOpts{}
	if query != "" {
		opts.Query = query
	}

	response, err := client.Search(context.Background(), opts)
	if err != nil {
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
		return nil, fmt.Errorf("error searching: %w", err)
	}

	results := gonotion.SearchResults{}
	for _, resultUntyped := range response.Results {
		switch result := resultUntyped.(type) {
		case gonotion.Database:
			if result.Archived {
				continue
			}
			results = append(results, result)
		case gonotion.Page:
			if result.Archived {
				continue
			}
			results = append(results, result)
		default:
			slog.Error("Unsupported search result type", "type", fmt.Sprintf("%T", result))
		}
	}

	return results, nil
}

func (f *notionFetcher) SearchDatabases(query string) ([]gonotion.Database, error) {
	client := gonotion.NewClient(f.accessToken)
	opts := &gonotion.SearchOpts{
		Filter: &gonotion.SearchFilter{
			Property: "object",
			Value:    "database",
		},
	}
	if query != "" {
		opts.Query = query
	}

	response, err := client.Search(context.Background(), opts)
	if err != nil {
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
		return nil, fmt.Errorf("error searching databases: %w", err)
	}

	databases := []gonotion.Database{}
	for _, resultUntyped := range response.Results {
		switch result := resultUntyped.(type) {
		case gonotion.Database:
			if result.Archived {
				continue
			}
			databases = append(databases, result)
		}
	}

	return databases, nil
}

func (f *notionFetcher) SearchPages(query string) ([]gonotion.Page, error) {
	client := gonotion.NewClient(f.accessToken)
	opts := &gonotion.SearchOpts{
		Filter: &gonotion.SearchFilter{
			Property: "object",
			Value:    "page",
		},
	}
	if query != "" {
		opts.Query = query
	}

	response, err := client.Search(context.Background(), opts)
	if err != nil {
		if errors.Is(err, gonotion.ErrUnauthorized) {
			return nil, lib_integ.ErrNotionInvalidToken
		}
		return nil, fmt.Errorf("error searching pages: %w", err)
	}

	pages := []gonotion.Page{}
	for _, resultUntyped := range response.Results {
		switch result := resultUntyped.(type) {
		case gonotion.Page:
			if result.Archived {
				continue
			}
			pages = append(pages, result)
		}
	}

	return pages, nil
}
