package notion

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"exnota.com/backend/integration/data"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"
)

type NotionSync interface {
	VerifyIntegration(request VerifyIntegrationRequest) error
}

func NewNotionSync(app core.App) NotionSync {
	return &notionSync{app}
}

type notionSync struct {
	app core.App
}

type VerifyIntegrationRequest struct {
	IntegrationId string `validate:"min=1"`
	UserID        string `validate:"min=1"`
}

var ErrAccessRevoked = fmt.Errorf("no access")

func (s *notionSync) VerifyIntegration(request VerifyIntegrationRequest) error {
	err := validate.Struct(request)
	if err != nil {
		return err
	}

	integrationFetcher := data.NewIntegrationFetcher(s.app)
	integration, err := integrationFetcher.FetchById(request.IntegrationId, request.UserID)
	if err != nil {
		return err
	}

	notionIntegration, ok := integration.(data.NotionIntegration)
	if !ok {
		slog.Error("Invalid integration type", "type", integration.Type())
		return errors.New("integration is not of type NotionIntegration")
	}

	config, err := notionIntegration.Config()
	if err != nil {
		slog.Error("Error getting notion integration config", "err", err)
		return err
	}

	// Verify access
	client := gonotion.NewClient(*config.Auth.AccessToken)
	opts := &gonotion.SearchOpts{
		Query:    "",
		PageSize: 1,
	}

	// The Notion API returns the same error whether then user revokes access in
	// Notion > Settings > My connections, or if the token is modified. This can
	// be useful for testing, as we can append a character to the token to
	// simulate a revoked token.
	//
	// If the user removes all shared pages/databases, no error will be returned
	// from the Notion API. It will just return an empty list of results.
	searchResponse, err := client.Search(context.Background(), opts)
	if err != nil {
		if errors.Unwrap(errors.Unwrap(err)) == gonotion.ErrUnauthorized {
			slog.Info("Unauthorized")
			return ErrAccessRevoked
		}
		slog.Error("Error doing verify search of notion", "err", err)
		return err
	}
	// TODO: Remove this
	slog.Info("Notion search response", "response", searchResponse)

	// 	// TODO: MOve all this into a service that can be called from a cron
	// 	// job or whatever in the future. Easier to move it now I think since
	// 	// we have to test that it works

	// 	// TODO: update a status on both the workspace and integration that it is not accessible
	// 	//   - maybe a data rule: When integration status changes, workspace status changes
	// 	// TODO: If access, get all destinations belonging to it.
	// 	// TODO: Ping them all to verify we have access
	// 	// TODO: Update their statuses to reflect the result
	// 	// TODO: Return success stastus of integration itself, ignore result of destinations

	// 	// TODO: Is this right?
	// 	// TODO: It's returning just "success"? What about {result:success}?
	// 	// ...does it work with other custom endpoints? Maybe needs to be a pointer?
	// 	//...ahh it's probably the Marshal function TODO: Fix that.
	return nil
}
