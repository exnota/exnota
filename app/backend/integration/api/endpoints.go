package api

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/url"
	"reflect"
	"strings"

	"exnota.com/backend/integration/data"
	"exnota.com/backend/integration/service"
	"exnota.com/backend/integration/util"
	"github.com/dstotijn/go-notion"
	"github.com/labstack/echo/v5"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type IntegrationEndpointHooks interface {
	Apply()
}

type integrationEndpointHooks struct {
	app    core.App
	config IntegrationEndpointConfig
}

type IntegrationEndpointConfig struct {
	BasePath       string
	NotionClientID string
	// Added this when I thought localhost redirect_uris wouldn't work. Turns
	// out they do but thought I'd leave this here for laziness sake.
	NotionRedirectBasePath string
}

func NewIntegrationEndpointHooks(app core.App, config IntegrationEndpointConfig) IntegrationEndpointHooks {
	return &integrationEndpointHooks{app: app, config: config}
}

func (h *integrationEndpointHooks) Apply() {
	h.notionMobileCodeRequestPath()
	h.notionMobileRedirect()
	h.notionSearch()
	h.integrationVerifyAccess()
}

const (
	// Use '/api' for consistent base paths and '/api/exnota' to avoid
	// collisions with future PocketBase URLs.
	notionMobileCodeRequestPath = "/api/exnota/integration/notion/mobile-code-request-path"
	notionMobileRedirectPath    = "/api/exnota/integration/notion/mobile-code-redirect"
	notionSearchPath            = "/api/exnota/integration/notion/search"
	integrationVerifyAccess     = "/api/exnota/integration/verify-access"
)

// Returns the URL the mobile app should use for getting a Notion auth code. Is
// specific for mobile because the redirect_uri points to mobileRedirect() which
// will redirect to an exnota:// scheme.
func (h *integrationEndpointHooks) notionMobileCodeRequestPath() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(notionMobileCodeRequestPath, func(c echo.Context) error {
			redirectUri, err := url.JoinPath(h.config.BasePath, notionMobileRedirectPath)
			if err != nil {
				return err
			}
			url := "https://api.notion.com/v1/oauth/authorize?client_id=" +
				h.config.NotionClientID +
				"&response_type=code&owner=user&redirect_uri=" +
				url.QueryEscape(redirectUri)

			// Manually constract this using a string + c.JSONBlob because
			// using json.Marshall (or c.JSON(), which calls json.Marshall) will
			// escape the redirect_uri.
			resp := `{"url":"` + url +
				`"}`
			slog.Info("", "json", resp)
			return c.JSONBlob(200, []byte(resp))
		})
		return nil
	})
}

// Redirects to an exnota:// scheme for the mobile app to capture and read.
func (h *integrationEndpointHooks) notionMobileRedirect() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(notionMobileRedirectPath, func(c echo.Context) error {
			code := c.QueryParam("code")
			return c.Redirect(302, "exnota://integration/notion/mobile-code-redirect?code="+code)
		})
		return nil
	})
}

type SearchRequest struct {
	Query  string  `json:"query"`
	Object *string `json:"object"`
}

type ObjectType string

const (
	ObjectTypePage     ObjectType = "page"
	ObjectTypeDatabase ObjectType = "database"
)

type SearchResponse struct {
	Results []SearchResult `json:"results"`
}

type SearchResult struct {
	Id         string     `json:"id"`
	Name       string     `json:"name"`
	Object     string     `json:"object"`
	ParentType ParentType `json:"parent_type"`
	ParentId   *string    `json:"parent_id"`
}

type ParentType string

const (
	ParentTypeDatabase  ParentType = "database"
	ParentTypePage      ParentType = "page"
	ParentTypeBlock     ParentType = "block"
	ParentTypeWorkspace ParentType = "workspace"
)

func (h *integrationEndpointHooks) notionSearch() {
	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(notionSearchPath, func(c echo.Context) error {

			searchRequest := new(SearchRequest)
			if err := c.Bind(searchRequest); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}

			if strings.TrimSpace(searchRequest.Query) == "" {
				return c.JSON(200, SearchResponse{Results: []SearchResult{}})
			}

			var object ObjectType
			if searchRequest.Object != nil {
				switch *searchRequest.Object {
				case string(ObjectTypePage):
					object = ObjectTypePage
				case string(ObjectTypeDatabase):
					object = ObjectTypeDatabase
				default:
					return c.String(http.StatusBadRequest, "bad request")
				}

			}

			requestInfo := apis.RequestInfo(c)
			userId := requestInfo.AuthRecord.Id

			response, err := h.executeNotionSearch(searchRequest.Query, object, userId)
			if err != nil {
				return err
			}
			return c.JSON(200, response)
		})
		return nil
	})
}

func (h *integrationEndpointHooks) executeNotionSearch(query string, object ObjectType, userId string) (*SearchResponse, error) {
	// Get integration
	filter := data.IntegrationFieldUser + "={:user} && " +
		data.IntegrationFieldType + "={:type}"
	integrationRecord, err := h.app.Dao().FindFirstRecordByFilter(
		data.CollectionIntegration,
		filter,
		dbx.Params{"user": userId, "type": data.IntegrationTypeNotion})
	if err != nil {
		return nil, err
	}
	integration, err := data.NewNotionIntegration(integrationRecord)
	if err != nil {
		return nil, err
	}

	// Config for integration
	config, err := integration.Config()
	if err != nil {
		return nil, err
	}

	// Send search to Notion
	client := notion.NewClient(*config.Auth.AccessToken)
	opts := &notion.SearchOpts{
		Query: query,
	}
	switch object {
	case ObjectTypePage:
		opts.Filter = &notion.SearchFilter{
			Property: "object",
			Value:    "page",
		}
	case ObjectTypeDatabase:
		opts.Filter = &notion.SearchFilter{
			Property: "object",
			Value:    "database",
		}
	}

	response, err := client.Search(context.Background(), opts)
	if err != nil {
		return nil, err
	}

	// Parse and map results
	results := []SearchResult{}
	for _, resultUntyped := range response.Results {
		switch result := resultUntyped.(type) {
		case notion.Page:
			parentType, parentId := h.mapParent(result.Parent)
			switch properties := result.Properties.(type) {
			case notion.PageProperties:
				results = append(results, SearchResult{
					Id:         result.ID,
					Name:       util.TitleToText(properties.Title.Title),
					Object:     "page",
					ParentType: parentType,
					ParentId:   parentId,
				})
				continue
			case notion.DatabasePageProperties:
				parentType, parentId := h.mapParent(result.Parent)
				for _, v := range properties {
					if v.Type == notion.DBPropTypeTitle {
						results = append(results, SearchResult{
							Id:         result.ID,
							Name:       util.TitleToText(v.Title),
							Object:     "page",
							ParentType: parentType,
							ParentId:   parentId,
						})
					}
				}
				continue
			default:
				slog.Warn("Unknown notion page type",
					"id", result.ID,
					"type", reflect.TypeOf(result),
					"parent", result.Parent,
				)
				continue
			}
		case notion.Database:
			parentType, parentId := h.mapParent(result.Parent)
			results = append(results, SearchResult{
				Id:         result.ID,
				Name:       util.TitleToText(result.Title),
				Object:     "database",
				ParentType: parentType,
				ParentId:   parentId,
			})
			continue
		default:
			slog.Warn("Unknown search result type",
				"type", reflect.TypeOf(result),
			)
			continue
		}
	}

	return &SearchResponse{
		Results: results,
	}, nil
}

func (h *integrationEndpointHooks) mapParent(parent notion.Parent) (parentType ParentType, parentId *string) {
	switch parent.Type {
	case notion.ParentTypeDatabase:
		parentType = ParentTypeDatabase
		parentId = &parent.DatabaseID
	case notion.ParentTypePage:
		parentType = ParentTypePage
		parentId = &parent.PageID
	case notion.ParentTypeBlock:
		parentType = ParentTypeBlock
		parentId = &parent.BlockID
	case notion.ParentTypeWorkspace:
		parentType = ParentTypeWorkspace
		parentId = nil
	default:
		slog.Warn("Unknown parent type")
	}
	return
}

type VerifyIntegrationAccessRequest struct {
	IntegrationId string `json:"integration_id"`
}

type VerifyIntegrationAccessResponse struct {
	Result VerifyIntegrationAccessResult
}

type VerifyIntegrationAccessResult string

const (
	Success      VerifyIntegrationAccessResult = "success"
	InvalidToken VerifyIntegrationAccessResult = "invalid-token"
)

func (r VerifyIntegrationAccessResponse) MarshalJSON() ([]byte, error) {
	return json.Marshal(struct {
		Result string `json:"result"`
	}{
		Result: string(r.Result),
	})
}

func (h *integrationEndpointHooks) integrationVerifyAccess() {

	h.app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET(integrationVerifyAccess, func(c echo.Context) error {
			verifyRequest := new(VerifyIntegrationAccessRequest)
			if err := c.Bind(verifyRequest); err != nil {
				return c.String(http.StatusBadRequest, "bad request")
			}

			if strings.TrimSpace(verifyRequest.IntegrationId) == "" {
				return c.JSON(http.StatusBadRequest, nil)
			}

			requestInfo := apis.RequestInfo(c)
			loggedInUserId := requestInfo.AuthRecord.Id

			integrationSync := service.NewIntegrationSync(h.app)
			success, err := integrationSync.UpdateStatus(service.UpdateStatusRequest{
				IntegrationId: verifyRequest.IntegrationId,
				UserID:        loggedInUserId,
			})
			if err != nil {
				return c.JSON(http.StatusInternalServerError, nil)
			}

			if success {
				return c.JSON(http.StatusOK, VerifyIntegrationAccessResponse{
					Result: Success,
				})
			} else {
				return c.JSON(http.StatusOK, VerifyIntegrationAccessResponse{
					Result: InvalidToken,
				})
			}

		})
		return nil
	})
}
