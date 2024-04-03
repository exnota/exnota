package data

import (
	"errors"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

const (
	CollectionDestination     = "destination"
	DestinationFieldName      = "name"
	DestinationFieldWorkspace = "workspace"
	DestinationFieldExternal  = "external"
	DestinationFieldUser      = "user"
)

type DestinationExternal struct {
	Config map[string]interface{} `json:"config"`
}

type Destination interface {
	Id() string
	Workspace() string
	Name() string
	External() *DestinationExternal
	User() string

	SetName(name string)

	Validate() error
}

type destination struct {
	record *models.Record
	app    core.App
}

func NewDestination(model models.Model, app core.App) (Destination, error) {
	record, ok := model.(*models.Record)
	if !ok {
		return nil, errors.New("invalid model")
	}

	return &destination{record: record, app: app}, nil
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

func (d *destination) External() *DestinationExternal {
	var external DestinationExternal
	// TODO:
	err := d.record.UnmarshalJSONField(DestinationFieldExternal, &external)
	if err != nil {
		return nil
	}
	return &external
}

func (d *destination) User() string {
	return d.record.GetString(DestinationFieldUser)
}

func (d *destination) SetName(name string) {
	d.record.Set(DestinationFieldName, name)
}

func (d *destination) Validate() error {
	form := forms.NewRecordUpsert(d.app, d.record)

	return form.Validate()
}
