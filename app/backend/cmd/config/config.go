package config

// For local development in VS Code, add to launch.json
type Config struct {
	BasePath                string `env:"BASE_PATH"                  validate:"min=1"`
	NotionRedirectBasePath  string `env:"NOTION_REDIRECT_BASE_PATH"  validate:"min=1"`
	NotionOAuthClientID     string `env:"NOTION_OAUTH_CLIENT_ID"     validate:"min=1"`
	NotionOAuthClientSecret string `env:"NOTION_OAUTH_CLIENT_SECRET" validate:"min=1"`
}
