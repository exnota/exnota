package main

// For local development in VS Code, add to launch.json
type Config struct {
	BasePath                string `env:"BASE_PATH" envDefault:"/"`
	BaseApiPath             string `env:"BASE_API_PATH" envDefault:"/api"`
	NotionOAuthClientID     string `env:"NOTION_OAUTH_CLIENT_ID"`
	NotionOAuthClientSecret string `env:"NOTION_OAUTH_CLIENT_SECRET"`
}
