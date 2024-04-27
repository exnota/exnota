package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	gonotion "github.com/dstotijn/go-notion"
)

// Adds functionality not supported by go-notion by copy/pasting and modifying.
type ExtendedClient struct {
	apiKey     string
	httpClient *http.Client
}

// Copied from client.go in go-notion
const (
	baseURL       = "https://api.notion.com/v1"
	apiVersion    = "2022-06-28"
	clientVersion = "0.0.0"
)

func NewExtendedClient(apiKey string /*, opts ...gonotion.ClientOption */) *ExtendedClient {
	c := &ExtendedClient{
		apiKey:     apiKey,
		httpClient: http.DefaultClient,
	}

	// for _, opt := range opts {
	// 	opt(c)
	// }

	return c
}

// Copied from client.go in go-notion, but adds support for 'after' parameter,
// which go-notion has omitted.
func (c *ExtendedClient) AppendBlockChildren(
	ctx context.Context,
	blockID string,
	children []gonotion.Block,
	afterId *string,
) (result gonotion.BlockChildrenResponse, err error) {
	type PostBody struct {
		Children []gonotion.Block `json:"children"`
		After    *string          `json:"after,omitempty"`
	}

	dto := PostBody{children, afterId}
	body := &bytes.Buffer{}

	err = json.NewEncoder(body).Encode(dto)
	if err != nil {
		return gonotion.BlockChildrenResponse{}, fmt.Errorf(
			"notion: failed to encode body params to JSON: %w",
			err,
		)
	}

	req, err := c.newRequest(
		ctx,
		http.MethodPatch,
		fmt.Sprintf("/blocks/%v/children", blockID),
		body,
	)
	if err != nil {
		return gonotion.BlockChildrenResponse{}, fmt.Errorf("notion: invalid request: %w", err)
	}

	res, err := c.httpClient.Do(req)
	if err != nil {
		return gonotion.BlockChildrenResponse{}, fmt.Errorf(
			"notion: failed to make HTTP request: %w",
			err,
		)
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return gonotion.BlockChildrenResponse{}, fmt.Errorf(
			"notion: failed to append block children: %w",
			parseErrorResponse(res),
		)
	}

	err = json.NewDecoder(res.Body).Decode(&result)
	if err != nil {
		return gonotion.BlockChildrenResponse{}, fmt.Errorf(
			"notion: failed to parse HTTP response: %w",
			err,
		)
	}

	return result, nil
}

// Copied from client.go in go-notion
func (c *ExtendedClient) newRequest(
	ctx context.Context,
	method, url string,
	body io.Reader,
) (*http.Request, error) {
	req, err := http.NewRequestWithContext(ctx, method, baseURL+url, body)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %v", c.apiKey))
	req.Header.Set("Notion-Version", apiVersion)
	req.Header.Set("User-Agent", "go-notion/"+clientVersion)

	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	return req, nil
}

// Copied from error.go in go-notion
func parseErrorResponse(res *http.Response) error {
	var apiErr gonotion.APIError

	err := json.NewDecoder(res.Body).Decode(&apiErr)
	if err != nil {
		return &gonotion.APIError{Status: res.StatusCode}
	}

	return &apiErr
}
