package url

import (
	"log/slog"
	"net/url"

	"github.com/pocketbase/pocketbase/core"
)

func Url(path string, app core.App) string {
	appUrl := app.Settings().Meta.AppUrl
	result, err := url.JoinPath(appUrl, path)
	if err != nil {
		slog.Error("Failed to join path", "path", path, "appUrl", appUrl)
		panic(err)
	}
	return result
}
