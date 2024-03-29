package api

import (
	"errors"

	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

type IntegrationType int

const (
	TypeNotion IntegrationType = iota
)

type Integration interface {
	Type() IntegrationType
}

func NewIntegration(r *models.Record) (Integration, error) {
	blockType := r.GetString(integ.IntegrationFieldType)
	switch blockType {
	case integ.IntegrationTypeNotion:
		var b NotionIntegration = &notionIntegration{
			record: r,
		}
		return b, nil
	}
	return nil, errors.New("Unknown integration type")
}

type NotionIntegration interface {
	Integration
	Config() (*notionIntegrationConfig, error)
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
	Owner                *string `json:"owner"`
	WorkspaceIcon        *string `json:"workspace_icon"`
	WorkspaceID          *string `json:"workspace_id"`
	WorkspaceName        *string `json:"workspace_name"`
}

func (i notionIntegration) Type() IntegrationType {
	return TypeNotion
}

func (i notionIntegration) Config() (*notionIntegrationConfig, error) {
	rawConfig := i.record.Get(integ.IntegrationFieldConfig).(types.JsonRaw)
	val, err := rawConfig.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return &notionIntegrationConfig{}, nil
	}

	var config notionIntegrationConfig
	err = i.record.UnmarshalJSONField(integ.IntegrationFieldConfig, &config)
	if err != nil {
		return nil, err
	}

	return &config, nil
}
