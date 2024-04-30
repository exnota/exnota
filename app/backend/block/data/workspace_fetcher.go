package data

import (
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type WorkspaceFetcher interface {
	FetchById(id string) (Workspace, error)
	FetchByIntegrationId(integrationId string) ([]Workspace, error)
}

type workspaceFetcher struct {
	app   core.App
	txDao *daos.Dao
}

func NewWorkspaceFetcher(app core.App, txDao *daos.Dao) WorkspaceFetcher {
	return &workspaceFetcher{app, txDao}
}

func (f *workspaceFetcher) FetchById(id string) (Workspace, error) {
	record, err := f.txDao.FindRecordById(CollectionWorkspace, id)
	if err != nil {
		return nil, err
	}
	workspace, err := LoadWorkspace(record, f.app)
	if err != nil {
		return nil, err
	}
	return workspace, nil
}

func (f *workspaceFetcher) FetchByIntegrationId(integrationId string) ([]Workspace, error) {
	integFilter, err := filter.CreateAndFilter(filter.Field{
		Name:  WorkspaceFieldIntegration,
		Op:    filter.OpEquals,
		Value: integrationId,
	})
	if err != nil {
		return nil, err
	}

	records, err := f.txDao.FindRecordsByFilter(
		CollectionWorkspace,
		integFilter.Filter,
		"",
		0,
		0,
		integFilter.Params,
	)
	if err != nil {
		return nil, err
	}

	workspaces := make([]Workspace, 0, len(records))
	for _, record := range records {
		workspace, err := LoadWorkspace(record, f.app)
		if err != nil {
			return nil, err
		}
		workspaces = append(workspaces, workspace)
	}
	return workspaces, nil
}
