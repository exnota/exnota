package data

import (
	"strconv"
	"strings"

	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/dbx"
)

type Field struct {
	Name string   `validate:"required"`
	Op   Operator `validate:"required"`
	// Use Value or ValuePreset, not both
	Value       string      `validate:"required_without=ValuePreset,excluded_with=ValuePreset"`
	ValuePreset ValuePreset `validate:"required_without=Value,excluded_with=Value"`
}

type Operator string

const (
	OpEquals         Operator = "="
	OpLessThanEquals Operator = "<="
)

type ValuePreset string

const (
	ValuePresetNow ValuePreset = "@now"
)

var validate = validator.New()

func CreateAndFilter(fields ...Field) (string, dbx.Params, error) {
	filterParts := make([]string, len(fields))
	params := dbx.Params{}
	for i, field := range fields {
		err := validate.Struct(field)
		if err != nil {
			return "", nil, err
		}

		paramName := "param" + strconv.Itoa(i+1)
		if field.ValuePreset == "" {
			filterParts[i] = field.Name + string(field.Op) + "{:" + paramName + "}"
			params[paramName] = field.Value
		} else {
			filterParts[i] = field.Name + string(field.Op) + string(field.ValuePreset)
		}
	}

	return strings.Join(filterParts, " && "), params, nil
}
