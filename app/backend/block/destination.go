package block

import (
	"encoding/json"
	"errors"
	"fmt"

	lib_integ "exnota.com/backend/lib/integration"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
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
	// Config is only used for passing the ID/type on create from the client.
	// Don't use it for linking the destination to the remote, integrated data.
	// For that, reference collections such as Integration Notion Object and
	// Integration Destination.
	Config map[string]interface{}       `json:"config"`
	Status lib_integ.NotionObjectStatus `json:"status"`
}

type Destination interface {
	Id() string
	Workspace() string
	Name() string
	External() (*DestinationExternal, error)
	User() string

	SetName(name string)
	SetExternalStatus(status lib_integ.NotionObjectStatus) error

	Validate() error
	ValidateAndSubmit(txDao *daos.Dao) error
}

type destination struct {
	record *models.Record
	app    core.App
}

func LoadDestination(model models.Model, app core.App) (Destination, error) {
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

func (d *destination) External() (*DestinationExternal, error) {
	var external DestinationExternal
	err := d.record.UnmarshalJSONField(DestinationFieldExternal, &external)
	if err != nil {
		return nil, err
	}
	return &external, nil
}

func (d *destination) User() string {
	return d.record.GetString(DestinationFieldUser)
}

func (d *destination) SetName(name string) {
	d.record.Set(DestinationFieldName, name)
}

func (d *destination) SetExternalStatus(status lib_integ.NotionObjectStatus) error {
	// Compose new data
	external, err := d.External()
	if err != nil {
		return err
	}
	if external == nil {
		external = &DestinationExternal{}
	}
	external.Status = status

	// Validate
	err = validate.Struct(external)
	if err != nil {
		return err
	}

	// Set
	configBytes, err := json.Marshal(external)
	if err != nil {
		return fmt.Errorf("failed to marshal external for destination %s: %w", d.Id(), err)
	}
	d.record.Set(DestinationFieldExternal, string(configBytes))

	return nil
}

func (d *destination) Validate() error {
	form := forms.NewRecordUpsert(d.app, d.record)

	return form.Validate()
}

func (d *destination) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(d.app, d.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}
