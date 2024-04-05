package data

import (
	"errors"
	"math/rand"
	"strings"

	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/dbx"
)

type Field struct {
	Name string   `validate:"required"`
	Op   Operator `validate:"required"`
	// Only one of the Value* fields should be set.
	//
	// Warning: The validator will likely interpret an empty string as the field
	// not being provided, and thus validation will fail if you meant to pass
	// an empty string for the field value.
	Value       string      `validate:"required_without_all=ValuePreset ValueInt"`
	ValuePreset ValuePreset `validate:"required_without_all=Value ValueInt"`
	ValueInt    *int        `validate:"required_without_all=Value ValuePreset"`
}

type Operator string

const (
	OpEquals         Operator = "="
	OpLessThanEquals Operator = "<="
	OpLessThan       Operator = "<"
)

type ValuePreset string

const (
	ValuePresetNow ValuePreset = "@now"
)

var validate = validator.New()

type Filter struct {
	Filter string
	Params dbx.Params
}

func CreateAndFilter(fields ...Field) (*Filter, error) {
	filterParts := make([]string, len(fields))
	params := dbx.Params{}
	for i, field := range fields {
		err := validate.Struct(field)
		if err != nil {
			return nil, err
		}

		// Generate a random param so the results of this function can be
		// combined with others and be unlikely to collide.
		//
		// Any grouping helpers should check for collisions anyway and error,
		// to prevent unintended side effects.
		paramName := "param-" + generateRandomString(4)
		if field.Value != "" {
			filterParts[i] = field.Name + string(field.Op) + "{:" + paramName + "}"
			params[paramName] = field.Value
		} else if field.ValuePreset != "" {
			filterParts[i] = field.Name + string(field.Op) + string(field.ValuePreset)
		} else if field.ValueInt != nil {
			filterParts[i] = field.Name + string(field.Op) + "{:" + paramName + "}"
			params[paramName] = field.ValueInt
		} else {
			return nil, errors.New("field must have a value")
		}
	}

	return &Filter{
		Filter: strings.Join(filterParts, " && "),
		Params: params,
	}, nil
}

func generateRandomString(length int) string {
	charset := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	result := make([]byte, length)
	for i := 0; i < length; i++ {
		result[i] = charset[rand.Intn(len(charset))]
	}
	return string(result)
}

func GroupFiltersWithOr(filters ...*Filter) (*Filter, error) {
	if len(filters) == 0 {
		return nil, errors.New("no filters provided")
	}

	filterParts := make([]string, len(filters))
	params := dbx.Params{}
	paramNames := make(map[string]bool) // Track used param names

	for i, filter := range filters {
		if filter == nil {
			return nil, errors.New("nil filter provided")
		}

		filterPart := "(" + filter.Filter + ")"
		filterParts[i] = filterPart

		for paramName, paramValue := range filter.Params {
			if paramNames[paramName] {
				return nil, errors.New("duplicate param name: " + paramName)
			}
			params[paramName] = paramValue
			paramNames[paramName] = true
		}
	}

	return &Filter{
		Filter: strings.Join(filterParts, " || "),
		Params: params,
	}, nil
}
