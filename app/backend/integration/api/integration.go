package api

import (
	integ "exnota.com/backend/integration"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

type Integration interface {
	Config() (*integrationConfig, error)
}

type integration struct {
	record *models.Record
}

type integrationConfig struct {
	auth integrationAuthConfig
}

type integrationAuthConfig struct {
	Code                 *string
	AccessToken          *string
	BotID                *string
	DuplicatedTemplateID *string
	Owner                *string
	WorkspaceIcon        *string
	WorkspaceID          *string
	WorkspaceName        *string
}

func NewIntegration(r *models.Record) (Integration, error) {
	return integration{
		record: r,
	}, nil
}

func (i integration) Config() (*integrationConfig, error) {
	rawConfig := i.record.Get(integ.IntegrationFieldConfig).(types.JsonRaw)
	val, err := rawConfig.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return &integrationConfig{}, nil
	}

	var config integrationConfig
	err = i.record.UnmarshalJSONField(integ.IntegrationFieldConfig, &config)
	if err != nil {
		return nil, err
	}

	return &config, nil
}
