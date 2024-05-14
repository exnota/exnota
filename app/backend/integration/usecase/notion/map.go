package notion

import (
	"fmt"

	"exnota.com/backend/integration/util"
	lib_integ "exnota.com/backend/lib/integration"
	gonotion "github.com/dstotijn/go-notion"
)

func mapDatabaseToDestination(database gonotion.Database) lib_integ.NotionDestination {
	if database.Archived {
		return lib_integ.NotionDestination{}
	}
	return lib_integ.NotionDestination{
		Name: util.TitleToText(database.Title),
		Object: lib_integ.NotionObject{
			ID:   database.ID,
			Type: "database",
		},
		Icon: mapIcon(database.Icon),
	}
}

func mapDatabasesToDestinations(
	databases []gonotion.Database,
) []lib_integ.NotionDestination {
	suggestions := []lib_integ.NotionDestination{}
	for _, db := range databases {
		if db.Archived {
			continue
		}
		suggestions = append(suggestions, mapDatabaseToDestination(db))
	}
	return suggestions
}

func mapPageToDestination(page gonotion.Page) (lib_integ.NotionDestination, error) {
	title, err := util.TitleForPage(&page)
	if err != nil {
		return lib_integ.NotionDestination{}, err
	}
	return lib_integ.NotionDestination{
		Name: title,
		Object: lib_integ.NotionObject{
			ID:   page.ID,
			Type: "page",
		},
		Icon: mapIcon(page.Icon),
	}, nil
}

func mapPagesToDestinations(
	pages []gonotion.Page,
) ([]lib_integ.NotionDestination, error) {
	suggestions := []lib_integ.NotionDestination{}
	for _, page := range pages {
		if page.Archived {
			continue
		}
		title, err := util.TitleForPage(&page)
		if err != nil {
			return nil, err
		}
		suggestions = append(suggestions, lib_integ.NotionDestination{
			Name: title,
			Object: lib_integ.NotionObject{
				ID:   page.ID,
				Type: "page",
			},
			Icon: mapIcon(page.Icon),
		})
	}
	return suggestions, nil
}

func mapSearchResultsToDestinations(
	results gonotion.SearchResults,
) ([]lib_integ.NotionDestination, error) {
	mapped := []lib_integ.NotionDestination{}
	for _, resultUntyped := range results {
		switch result := resultUntyped.(type) {
		case gonotion.Database:
			if result.Archived {
				continue
			}
			mapped = append(mapped, mapDatabaseToDestination(result))
		case gonotion.Page:
			if result.Archived {
				continue
			}
			page, err := mapPageToDestination(result)
			if err != nil {
				return nil, err
			}
			mapped = append(mapped, page)
		default:
			return nil, fmt.Errorf("unknown search result type: %T", result)
		}
	}
	return mapped, nil
}
