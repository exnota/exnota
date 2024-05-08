package block

import "github.com/pocketbase/pocketbase/daos"

type BlockFetcher interface {
	FetchById(id string) (Block, error)
}

type DestinationFetcher interface {
	FetchById(id string) (Destination, error)
	ListIdsByIntegrationId(workspaceIntegrationId string) ([]string, error)
}

type WorkspaceFetcher interface {
	FetchById(id string) (Workspace, error)
	FetchByIntegrationId(integrationId string) ([]Workspace, error)
	FetchByIntegrationIdInTx(integrationId string, txDao *daos.Dao) ([]Workspace, error)
	ListUnarchived(userId string) ([]Workspace, error)
}
