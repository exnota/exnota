package block

import (
	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/daos"
)

type BlockFetcher interface {
	FetchById(id string) (Block, error)
	FetchVoiceNoteByIdInTx(txDao *daos.Dao, id string) (VoiceNoteBlock, error)
}

type DestinationFetcher interface {
	FetchById(id string) (Destination, error)
	Exists(id string) error
	// List unarchived destination IDs for an integration ID
	ListIDsByIntegrationID(workspaceIntegrationId string) ([]string, error)
	// All unarchived destinations for a workspace
	ListByWorkspace(workspaceId string) ([]Destination, error)
}

type DestinationWriter interface {
	Update(request DestinationUpdateRequest) error
	ArchiveForWorkspace(workspaceId string) error
}

type DestinationUpdateRequest struct {
	Id string `validate:"min=1"`
	// Name has min length of 1 in the Destination collection
	Name         string                       `validate:"min=1"`
	NotionStatus lib_integ.NotionObjectStatus `validate:"required"`
}

type WorkspaceFetcher interface {
	FetchById(id string) (Workspace, error)
	FetchByIntegrationId(integrationId string) ([]Workspace, error)
	FetchByIntegrationIdInTx(integrationId string, txDao *daos.Dao) ([]Workspace, error)
	ListUnarchived(userId string) ([]Workspace, error)
}
