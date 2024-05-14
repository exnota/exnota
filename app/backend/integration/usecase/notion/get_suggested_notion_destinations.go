package notion

import (
	"log/slog"
	"sort"

	integ "exnota.com/backend/integration"
	"exnota.com/backend/integration/usecase/notion/api"
	"exnota.com/backend/integration/util"
	lib "exnota.com/backend/lib/integration"
	gonotion "github.com/dstotijn/go-notion"
	"github.com/pocketbase/pocketbase/core"
)

const maxSuggestions = 4
const maxWorkspaceLevelSuggestions = 2

type GetSuggestedNotionDestinations interface {
	Get(
		request lib.GetSuggestedDestinationsRequest,
	) ([]lib.NotionDestination, error)
}

type getSuggestedNotionDestinations struct {
	app                core.App
	integrationFetcher integ.IntegrationFetcher
}

func NewGetSuggestedNotionDestinations(
	app core.App,
	integrationFetcher integ.IntegrationFetcher,
) GetSuggestedNotionDestinations {
	return &getSuggestedNotionDestinations{
		app,
		integrationFetcher,
	}
}

func (s *getSuggestedNotionDestinations) Get(
	request lib.GetSuggestedDestinationsRequest,
) ([]lib.NotionDestination, error) {
	if request.WorkspaceType != lib.WorkspaceTypeDatabase {
		slog.Info("Workspace type not supported", "workspaceType", request.WorkspaceType)
		return []lib.NotionDestination{}, nil
	}

	integration, err := s.integrationFetcher.FetchNotionIntegration(request.IntegrationID)
	if err != nil {
		return nil, err
	}
	config, err := integration.Config()
	if err != nil {
		return nil, err

	}

	fetcher := api.NewNotionFetcher(*config.Auth.AccessToken)
	// Search for databases with "notes" in the name
	notesDatabases, err := fetcher.SearchDatabases("notes")
	if err != nil {
		return nil, err
	}
	suggestions := searchResultsToSuggestions(notesDatabases)

	allDatabases := []gonotion.Database{}
	if len(suggestions) == 0 {
		slog.Info("No databases with \"notes\" in the name found")

		// Search all databases
		allDatabases, err = fetcher.SearchDatabases("")
		if err != nil {
			return nil, err
		}
		suggestions = searchResultsToSuggestions(allDatabases)
	}

	if len(suggestions) > maxSuggestions {
		// Get a list of recent pages. This will be used to determine what
		// the most popular databases are for pages to be children of.
		recentPages, err := fetcher.SearchPages("")
		if err != nil {
			return nil, err
		}
		suggestions = trimDatabaseSuggestions(allDatabases, recentPages, suggestions)
	}

	return suggestions, nil
}

func searchResultsToSuggestions(
	databases []gonotion.Database,
) []lib.NotionDestination {
	suggestions := []lib.NotionDestination{}
	for _, db := range databases {
		if db.Archived {
			continue
		}
		suggestions = append(suggestions, lib.NotionDestination{
			Name: util.TitleToText(db.Title),
			Object: lib.NotionObject{
				ID:     db.ID,
				Object: "database",
			},
			Icon: mapIcon(db.Icon),
		})
	}
	return suggestions
}

// Prioritises workspace-level suggestions and popular parent
// suggestions.
func trimDatabaseSuggestions(
	databases []gonotion.Database,
	recentPages []gonotion.Page,
	suggestions []lib.NotionDestination,
) []lib.NotionDestination {
	// Workspace-level suggestions
	//
	// Get all databases that are at workspace level
	workspaceLevelDatabases := make(map[string]bool)
	for _, db := range databases {
		if db.Parent.Type == gonotion.ParentTypeWorkspace {
			workspaceLevelDatabases[db.ID] = true
		}
	}
	// Choose the suggestions that are in the workspace list
	workspaceLevelSuggestions := make([]lib.NotionDestination, 0)
	for _, suggestion := range suggestions {
		if workspaceLevelDatabases[suggestion.Object.ID] {
			workspaceLevelSuggestions = append(workspaceLevelSuggestions, suggestion)
		}
	}
	// Trim to max
	if len(workspaceLevelSuggestions) > maxWorkspaceLevelSuggestions {
		workspaceLevelSuggestions = workspaceLevelSuggestions[:maxWorkspaceLevelSuggestions]
	}

	// Popular parent suggestions
	//
	// Count the number of appearances of each database in the parent field of
	// recent pages.
	databaseParentCounts := make(map[string]int)
	for _, page := range recentPages {
		switch page.Parent.Type {
		case gonotion.ParentTypeDatabase:
			databaseParentCounts[page.Parent.DatabaseID]++
		default:
			continue
		}
	}

	numPopularParentsToChoose := maxSuggestions - len(workspaceLevelSuggestions)
	popularParentSuggestions := make([]lib.NotionDestination, 0)
	for _, suggestion := range suggestions {
		// if databaseParentCounts[suggestion.Object.ID] > 0 {
		// Exclude suggestions that are already in workspaceLevelSuggestions
		found := false
		for _, workspaceSuggestion := range workspaceLevelSuggestions {
			if suggestion.Object.ID == workspaceSuggestion.Object.ID {
				found = true
				break
			}
		}
		if !found {
			popularParentSuggestions = append(popularParentSuggestions, suggestion)
		}
		// }
	}
	sort.Slice(popularParentSuggestions, func(i, j int) bool {
		return databaseParentCounts[popularParentSuggestions[i].Object.ID] > databaseParentCounts[popularParentSuggestions[j].Object.ID]
	})
	if len(popularParentSuggestions) > numPopularParentsToChoose {
		popularParentSuggestions = popularParentSuggestions[:numPopularParentsToChoose]
	}

	return append(workspaceLevelSuggestions, popularParentSuggestions...)
}

func mapIcon(icon *gonotion.Icon) *lib.NotionIcon {
	if icon == nil {
		return nil
	}
	switch icon.Type {
	case gonotion.IconTypeEmoji:
		return &lib.NotionIcon{
			Type:  lib.IconTypeEmoji,
			Emoji: icon.Emoji,
		}
	case gonotion.IconTypeFile:
		return &lib.NotionIcon{
			Type: lib.IconTypeURL,
			URL:  &icon.File.URL,
		}
	case gonotion.IconTypeExternal:
		return &lib.NotionIcon{
			Type: lib.IconTypeURL,
			URL:  &icon.External.URL,
		}
	default:
		slog.Error("Unknown icon type", "type", icon.Type)
		return nil
	}
}
