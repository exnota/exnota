package data

import (
	"github.com/pocketbase/pocketbase/core"
)

type WorkspaceFetcher interface {
	FetchById(id string) (Workspace, error)
}

type workspaceFetcher struct {
	app core.App
}

func NewWorkspaceFetcher(app core.App) WorkspaceFetcher {
	return &workspaceFetcher{app}
}

func (f *workspaceFetcher) FetchById(id string) (Workspace, error) {
	record, err := f.app.Dao().FindRecordById(CollectionWorkspace, id)
	if err != nil {
		return nil, err
	}
	workspace, err := NewWorkspace(record)
	if err != nil {
		return nil, err
	}
	return workspace, nil
}
