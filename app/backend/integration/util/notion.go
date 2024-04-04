package util

import (
	"errors"
	"log/slog"
	"reflect"

	"github.com/dstotijn/go-notion"
)

func TitleToText(title []notion.RichText) (text string) {
	for _, textSlice := range title {
		text += textSlice.PlainText
	}
	return
}

func TitleForPage(page *notion.Page) (string, error) {
	switch page.Properties.(type) {
	case notion.PageProperties:
		return TitleToText(page.Properties.(notion.PageProperties).Title.Title), nil
	case notion.DatabasePageProperties:
		for _, prop := range page.Properties.(notion.DatabasePageProperties) {
			if prop.Type == notion.DBPropTypeTitle {
				return TitleToText(prop.Title), nil
			}
		}
		return "", errors.New("title not found for page")
	default:
		slog.Warn("Unknown notion page type", "id", page.ID, "type", reflect.TypeOf(page))
		return "", errors.New("unknown notion page type")
	}
}
