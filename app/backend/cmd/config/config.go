package config

import (
	"github.com/caarlos0/env"
	"github.com/go-playground/validator/v10"
)

var validate = validator.New(validator.WithRequiredStructEnabled())

// For local development in VS Code, add to launch.json
type Config struct {
	NotionOAuthClientID     string `env:"NOTION_OAUTH_CLIENT_ID"     validate:"min=1"`
	NotionOAuthClientSecret string `env:"NOTION_OAUTH_CLIENT_SECRET" validate:"min=1"`
	// Whisper default is 4 threads
	WhisperThreads int    `env:"WHISPER_THREADS"                             envDefault:"4"`
	OpenAIKey      string `env:"OPENAI_KEY"                 validate:"min=1"`
}

func ReadConfig() Config {
	cfg := Config{}
	err := env.Parse(&cfg)
	if err != nil {
		panic(err)
	}
	err = validate.Struct(cfg)
	if err != nil {
		panic(err)
	}

	return cfg
}
