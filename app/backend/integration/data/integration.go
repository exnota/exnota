package data

import (
	"errors"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionIntegration = "integration"

	IntegrationFieldUser = "user"

	IntegrationFieldConfig = "config"

	IntegrationFieldType  = "type"
	IntegrationTypeNotion = "notion"

	IntegrationFieldStatus   = "status"
	IntegrationFieldArchived = "archived"
)

type IntegrationType string

const (
	TypeNotion IntegrationType = IntegrationTypeNotion
)

type IntegrationStatus string

const (
	// If updating, also update ValidatedStatus `oneof` options
	IntegrationStatusConnected     IntegrationStatus = "connected"
	IntegrationStatusAccessRevoked IntegrationStatus = "access-revoked"
)

// Shared wrapper struct so that we can keep all 'oneof' validation logic in
// one place.
type ValidatedIntegrationStatus struct {
	Status IntegrationStatus `validate:"oneof=connected access-revoked"`
}

type Integration interface {
	Id() string
	Type() IntegrationType
	Status() IntegrationStatus
	User() string
	Archived() time.Time

	SetStatus(status IntegrationStatus)

	ValidateAndSubmit(txDao *daos.Dao) error
}

func LoadIntegration(r *models.Record, app core.App) (Integration, error) {
	blockType := r.GetString(IntegrationFieldType)
	switch blockType {
	case IntegrationTypeNotion:
		var b NotionIntegration = &notionIntegration{
			integration: integration{
				record: r,
				app:    app,
			},
		}
		return b, nil
	}
	return nil, errors.New("Unknown integration type")
}

type integration struct {
	record *models.Record
	app    core.App
}

func (i integration) Id() string {
	return i.record.Id
}

func (i integration) Type() IntegrationType {
	return TypeNotion
}

func (i integration) Status() IntegrationStatus {
	return IntegrationStatus(i.record.GetString(IntegrationFieldStatus))
}

func (i integration) User() string {
	return i.record.GetString(IntegrationFieldUser)
}

func (i integration) Archived() time.Time {
	return i.record.GetDateTime(IntegrationFieldArchived).Time()
}

func (i integration) SetStatus(status IntegrationStatus) {
	i.record.Set(IntegrationFieldStatus, string(status))
}

func (i *integration) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(i.app, i.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}

type NotionIntegration interface {
	Integration

	Config() (*NotionIntegrationConfig, error)

	SetSuccessfulAuth(auth SuccessfulNotionIntegrationAuth) error
}

type notionIntegration struct {
	integration
}

type NotionIntegrationConfig struct {
	Auth NotionIntegrationAuthConfig `json:"auth,omitempty"`
}

type NotionIntegrationAuthConfig struct {
	Code                 *string `json:"code"`
	AccessToken          *string `json:"access_token"`
	BotID                *string `json:"bot_id"`
	DuplicatedTemplateID *string `json:"duplicated_template_id"`
	OwnerUserId          *string `json:"owner_user_id"`
	WorkspaceIcon        *string `json:"workspace_icon"`
	WorkspaceID          *string `json:"workspace_id"`
	WorkspaceName        *string `json:"workspace_name"`
}

const FilterConfigBotId = IntegrationFieldConfig + ".auth.bot_id"

// Returns error if not of type notion.
func LoadNotionIntegration(r *models.Record, app core.App) (NotionIntegration, error) {
	blockType := r.GetString(IntegrationFieldType)
	switch blockType {
	case IntegrationTypeNotion:
		var b NotionIntegration = &notionIntegration{
			integration: integration{
				record: r,
				app:    app,
			},
		}
		return b, nil
	}
	return nil, errors.New("Not a notion integration")
}

type SuccessfulNotionIntegrationAuth struct {
	AccessToken          string
	BotID                string
	DuplicatedTemplateID *string
	OwnerUserId          *string
	WorkspaceIcon        string
	WorkspaceID          string
	WorkspaceName        string
}

func (i notionIntegration) Config() (*NotionIntegrationConfig, error) {
	rawConfig := i.record.Get(IntegrationFieldConfig).(types.JsonRaw)
	val, err := rawConfig.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return &NotionIntegrationConfig{}, nil
	}

	var config NotionIntegrationConfig
	err = i.record.UnmarshalJSONField(IntegrationFieldConfig, &config)
	if err != nil {
		return nil, err
	}

	return &config, nil
}

func (i notionIntegration) SetSuccessfulAuth(auth SuccessfulNotionIntegrationAuth) error {
	config, err := i.Config()
	if err != nil {
		return err
	}
	config.Auth = NotionIntegrationAuthConfig{
		AccessToken:          &auth.AccessToken,
		BotID:                &auth.BotID,
		DuplicatedTemplateID: auth.DuplicatedTemplateID,
		OwnerUserId:          auth.OwnerUserId,
		WorkspaceID:          &auth.WorkspaceID,
		WorkspaceName:        &auth.WorkspaceName,
		WorkspaceIcon:        &auth.WorkspaceIcon,
	}
	i.record.Set(IntegrationFieldConfig, config)
	return nil
}
