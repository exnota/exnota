package integration

type Destinations struct {
	Notion []NotionDestination `json:"notion,omitempty"`
}

type NotionDestination struct {
	Name   string       `json:"name"           validate:"required"`
	Object NotionObject `json:"object"         validate:"required"`
	Icon   *NotionIcon  `json:"icon,omitempty"`
}

type NotionObject struct {
	ID   string `json:"id"   validate:"required"`
	Type string `json:"type" validate:"oneof=database page"`
}

type IconType string

const (
	IconTypeEmoji IconType = "emoji"
	// Consolidate Notion's 'file' and 'external' type to 'url'
	IconTypeURL IconType = "url"
)

type NotionIcon struct {
	Type  IconType `json:"type"            validate:"required,oneof=emoji url"`
	Emoji *string  `json:"emoji,omitempty"`
	URL   *string  `json:"url,omitempty"   validate:"omitempty,url"`
}
