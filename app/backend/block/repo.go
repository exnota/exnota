package block

type BlockFetcher interface {
	FetchById(id string) (Block, error)
}

type DestinationFetcher interface {
	FetchById(id string) (Destination, error)
}
