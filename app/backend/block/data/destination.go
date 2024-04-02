package data

import (
	"errors"

	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionDestination     = "destination"
	DestinationFieldName      = "name"
	DestinationFieldWorkspace = "workspace"
	DestinationFieldUser      = "user"
)

type Destination interface {
	Id() string
	Name() string
	Workspace() string
	User() string
}

type destination struct {
	record *models.Record
}

func NewDestination(model models.Model) (Destination, error) {
	record, ok := model.(*models.Record)
	if !ok {
		return nil, errors.New("invalid model")
	}

	return &destination{record: record}, nil
}

func (d *destination) Id() string {
	return d.record.Id
}

func (d *destination) Name() string {
	return d.record.GetString(DestinationFieldName)
}

func (d *destination) Workspace() string {
	return d.record.GetString(DestinationFieldWorkspace)
}

func (d *destination) User() string {
	return d.record.GetString(DestinationFieldUser)
}
