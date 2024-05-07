package data

import (
	"exnota.com/backend/block"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
)

type WorkspaceWriter interface {
	SetExternalStatus(request SetStatusRequest) error
}

type workspaceWriter struct {
	app   core.App
	txDao *daos.Dao
}

func NewWorkspaceWriter(app core.App, txDao *daos.Dao) WorkspaceWriter {
	return &workspaceWriter{app, txDao}
}

type SetStatusRequest struct {
	Id     string
	Status block.WorkspaceExternalStatus
}

func (f *workspaceWriter) SetExternalStatus(request SetStatusRequest) error {
	record, err := f.txDao.FindRecordById(block.CollectionWorkspace, request.Id)
	if err != nil {
		return err
	}
	workspace, err := block.LoadWorkspace(record, f.app)
	if err != nil {
		return err
	}

	err = workspace.SetExternalStatus(request.Status)
	if err != nil {
		return err
	}

	err = workspace.ValidateAndSubmit(f.txDao)
	if err != nil {
		return err
	}

	return nil
}
