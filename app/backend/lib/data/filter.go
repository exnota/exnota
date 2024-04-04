package filter

import (
	"strconv"
	"strings"

	"github.com/pocketbase/dbx"
)

type Field struct {
	Name  string
	Value string
}

func CreateAndFilter(fields ...Field) (string, dbx.Params) {
	filterParts := make([]string, len(fields))
	params := dbx.Params{}
	for i, field := range fields {
		paramName := "param" + strconv.Itoa(i+1)
		filterParts[i] = field.Name + "={:" + paramName + "}"
		params[paramName] = field.Value
	}

	return strings.Join(filterParts, " && "), params
}
