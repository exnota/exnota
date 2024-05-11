package block

import "github.com/pocketbase/pocketbase/daos"

type BlockFetcher interface {
	FetchById(id string) (Block, error)
}

type DestinationFetcher interface {
	FetchById(id string) (Destination, error)
	ListIdsByIntegrationId(workspaceIntegrationId string) ([]string, error)
}

type DestinationWriter interface {
	Update(request DestinationUpdateRequest) error
}

type DestinationUpdateRequest struct {
	Id string `validate:"min=1"`
	// Name has min length of 1 in the Destination collection
	Name string `validate:"min=1"`
}

type WorkspaceFetcher interface {
	FetchById(id string) (Workspace, error)
	FetchByIntegrationId(integrationId string) ([]Workspace, error)
	FetchByIntegrationIdInTx(integrationId string, txDao *daos.Dao) ([]Workspace, error)
	ListUnarchived(userId string) ([]Workspace, error)
}
