package main

type Config struct {
	NotionOAuthClientID     string `env:"NOTION_OAUTH_CLIENT_ID"`
	NotionOAuthClientSecret string `env:"NOTION_OAUTH_CLIENT_SECRET"`
}
