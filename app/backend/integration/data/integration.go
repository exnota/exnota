package data

import (
	"errors"

	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionIntegration = "integration"

	IntegrationFieldUser = "user"

	IntegrationFieldConfig = "config"

	IntegrationFieldType  = "type"
	IntegrationTypeNotion = "notion"
)

type IntegrationType int

const (
	TypeNotion IntegrationType = iota
)

type Integration interface {
	Id() string
	Type() IntegrationType
	User() string
}

func NewIntegration(r *models.Record) (Integration, error) {
	blockType := r.GetString(IntegrationFieldType)
	switch blockType {
	case IntegrationTypeNotion:
		var b NotionIntegration = &notionIntegration{
			record: r,
		}
		return b, nil
	}
	return nil, errors.New("Unknown integration type")
}

// Returns error if not of type notion.
func NewNotionIntegration(r *models.Record) (NotionIntegration, error) {
	blockType := r.GetString(IntegrationFieldType)
	switch blockType {
	case IntegrationTypeNotion:
		var b NotionIntegration = &notionIntegration{
			record: r,
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

type NotionIntegration interface {
	Integration
	Config() (*notionIntegrationConfig, error)
	SetSuccessfulAuth(auth SuccessfulNotionIntegrationAuth) error
}

type notionIntegration struct {
	record *models.Record
}

type notionIntegrationConfig struct {
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

func (i notionIntegration) Id() string {
	return i.record.Id
}

func (i notionIntegration) Type() IntegrationType {
	return TypeNotion
}

func (i notionIntegration) User() string {
	return i.record.GetString(IntegrationFieldUser)
}

func (i notionIntegration) Config() (*notionIntegrationConfig, error) {
	rawConfig := i.record.Get(IntegrationFieldConfig).(types.JsonRaw)
	val, err := rawConfig.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return &notionIntegrationConfig{}, nil
	}

	var config notionIntegrationConfig
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
