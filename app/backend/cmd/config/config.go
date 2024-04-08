package config

// For local development in VS Code, add to launch.json
type Config struct {
	BasePath                string `env:"BASE_PATH"`
	NotionRedirectBasePath  string `env:"NOTION_REDIRECT_BASE_PATH"`
	NotionOAuthClientID     string `env:"NOTION_OAUTH_CLIENT_ID"`
	NotionOAuthClientSecret string `env:"NOTION_OAUTH_CLIENT_SECRET"`
}
