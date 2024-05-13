package integration

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
