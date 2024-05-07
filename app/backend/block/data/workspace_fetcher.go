package data

import (
	"exnota.com/backend/block"
	"exnota.com/backend/lib/data/filter"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type workspaceFetcher struct {
	app core.App
}

func NewWorkspaceFetcher(app core.App) block.WorkspaceFetcher {
	return &workspaceFetcher{app}
}

func (f *workspaceFetcher) FetchById(id string) (block.Workspace, error) {
	record, err := f.app.Dao().FindRecordById(block.CollectionWorkspace, id)
	if err != nil {
		return nil, err
	}
	workspace, err := block.LoadWorkspace(record, f.app)
	if err != nil {
		return nil, err
	}
	return workspace, nil
}

func (f *workspaceFetcher) FetchByIntegrationId(integrationId string) ([]block.Workspace, error) {
	return f.FetchByIntegrationIdInTx(integrationId, f.app.Dao())
}

func (f *workspaceFetcher) FetchByIntegrationIdInTx(
	integrationId string,
	txDao *daos.Dao,
) ([]block.Workspace, error) {
	integFilter, err := filter.CreateAndFilter(filter.Field{
		Name:  block.WorkspaceFieldIntegration,
		Op:    filter.OpEquals,
		Value: integrationId,
	})
	if err != nil {
		return nil, err
	}

	records, err := txDao.FindRecordsByFilter(
		block.CollectionWorkspace,
		integFilter.Filter,
		"",
		0,
		0,
		integFilter.Params,
	)
	if err != nil {
		return nil, err
	}

	workspaces := make([]block.Workspace, 0, len(records))
	for _, record := range records {
		workspace, err := block.LoadWorkspace(record, f.app)
		if err != nil {
			return nil, err
		}
		workspaces = append(workspaces, workspace)
	}
	return workspaces, nil
}

func (f *workspaceFetcher) ListUnarchived(userId string) ([]block.Workspace, error) {
	archivedFilter, err := filter.CreateAndFilter(
		filter.Field{
			Name:        block.WorkspaceFieldArchived,
			Op:          filter.OpEquals,
			ValuePreset: filter.ValuePresetNull,
		},
		filter.Field{
			Name:  block.WorkspaceFieldUser,
			Op:    filter.OpEquals,
			Value: userId,
		},
	)
	if err != nil {
		return nil, err
	}

	records, err := f.app.Dao().FindRecordsByFilter(
		block.CollectionWorkspace,
		archivedFilter.Filter,
		"",
		0,
		0,
		archivedFilter.Params,
	)
	if err != nil {
		return nil, err
	}

	workspaces := make([]block.Workspace, 0, len(records))
	for _, record := range records {
		workspace, err := block.LoadWorkspace(record, f.app)
		if err != nil {
			return nil, err
		}
		workspaces = append(workspaces, workspace)
	}
	return workspaces, nil
}
