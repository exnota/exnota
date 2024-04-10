package data

import (
	"encoding/json"
	"fmt"
	"time"

	"log/slog"

	"github.com/go-playground/validator/v10"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

var validate = validator.New(validator.WithRequiredStructEnabled())

const (
	CollectionBlockJob      = "block_job"
	BlockJobFieldType       = "type"
	BlockJobFieldStatus     = "status"
	BlockJobFieldSummary    = "summary"
	BlockJobFieldBlock      = "block"
	BlockJobFieldUser       = "user"
	BlockJobFieldNextRunAt  = "next_run_at"
	BlockJobFieldErrorCount = "error_count"
	BlockJobFieldConfig     = "config"
)

type BlockJobStatus string

const (
	BlockJobStatusWaiting  BlockJobStatus = "waiting"
	BlockJobStatusRunning  BlockJobStatus = "running"
	BlockJobStatusComplete BlockJobStatus = "complete"
	BlockJobStatusError    BlockJobStatus = "error"
)

type BlockJobType string

const (
	BlockJobTypeTranscription BlockJobType = "transcription"
	BlockJobTypeExport        BlockJobType = "export"
)

type BlockJob interface {
	Record() *models.Record

	ID() string
	Type() BlockJobType
	Status() BlockJobStatus
	Summary() string
	Block() string
	User() string
	NextRunAt() time.Time
	ErrorCount() int

	SetType(t BlockJobType)
	SetStatus(status BlockJobStatus)
	SetSummaryError(err error)
	SetSummaryEmpty()
	SetBlock(blockId string)
	SetUser(userId string)
	SetNextRunAt(nextRunAt time.Time)
	IncrementErrorCount()
	ClearErrorCount()

	ValidateAndSubmit(txDao *daos.Dao) error
}

func NewBlockJob(r *models.Record, app core.App) (BlockJob, error) {
	switch BlockJobType(r.GetString(BlockJobFieldType)) {
	case BlockJobTypeTranscription:
		return NewTranscriptionBlockJob(r, app)
	case BlockJobTypeExport:
		return NewExportBlockJob(r, app)
	default:
		return nil, fmt.Errorf("unknown block job type: %s", r.GetString(BlockJobFieldType))
	}
}

// ----------------------------
// Block Job base
// ----------------------------

type blockJob struct {
	record *models.Record
	app    core.App
}

func (j *blockJob) ID() string {
	return j.record.Id
}

func (j *blockJob) Status() BlockJobStatus {
	return BlockJobStatus(j.record.GetString(BlockJobFieldStatus))
}

func (j *blockJob) Summary() string {
	result := j.record.GetString(BlockJobFieldSummary)
	return result
}

func (j *blockJob) Type() BlockJobType {
	return BlockJobType(j.record.GetString(BlockJobFieldType))
}

func (j *blockJob) Record() *models.Record {
	return j.record
}

func (j *blockJob) Block() string {
	return j.record.GetString(BlockJobFieldBlock)
}

func (j *blockJob) User() string {
	return j.record.GetString(BlockJobFieldUser)
}

func (j *blockJob) NextRunAt() time.Time {
	return j.record.GetDateTime(BlockJobFieldNextRunAt).Time()
}

func (j *blockJob) ErrorCount() int {
	return j.record.GetInt(BlockJobFieldErrorCount)
}

func (j *blockJob) SetType(t BlockJobType) {
	j.record.Set(BlockJobFieldType, string(t))
}

func (j *blockJob) SetStatus(status BlockJobStatus) {
	j.record.Set(BlockJobFieldStatus, string(status))
}

type SummaryError struct {
	Error string `json:"errors" validate:"required"`
}

func (j *blockJob) SetSummaryError(err error) {
	j.record.Set(BlockJobFieldSummary, SummaryError{
		Error: err.Error(),
	})
}

func (j *blockJob) SetSummaryEmpty() {
	j.record.Set(BlockJobFieldSummary, nil)
}

func (j *blockJob) SetBlock(blockId string) {
	j.record.Set(BlockJobFieldBlock, blockId)
}

func (j *blockJob) SetUser(userId string) {
	j.record.Set(BlockJobFieldUser, userId)
}

func (j *blockJob) SetNextRunAt(nextRunAt time.Time) {
	j.record.Set(BlockJobFieldNextRunAt, nextRunAt)
}

func (j *blockJob) IncrementErrorCount() {
	j.record.Set(BlockJobFieldErrorCount, j.ErrorCount()+1)
}

func (j *blockJob) ClearErrorCount() {
	j.record.Set(BlockJobFieldErrorCount, 0)
}

func (j *blockJob) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(j.app, j.record)
	form.SetDao(txDao)

	if err := form.Validate(); err != nil {
		return err
	}

	return form.Submit()
}

// ----------------------------
// Transcription Block Job
// ----------------------------

type TranscriptionBlockJob interface {
	BlockJob
}

type transcriptionBlockJob struct {
	blockJob
}

func NewTranscriptionBlockJob(r *models.Record, app core.App) (TranscriptionBlockJob, error) {
	// if wrong type, return error
	if BlockJobType(r.GetString(BlockJobFieldType)) != BlockJobTypeTranscription {
		return nil, fmt.Errorf("Not a transcription job: %s", r.GetString(BlockJobFieldType))
	}

	return &transcriptionBlockJob{
		blockJob: blockJob{
			record: r,
			app:    app,
		},
	}, nil
}

// ----------------------------
// Export Block Job base
// ----------------------------

type ExportJobCommand string

const (
	ExportJobCommandCreateVoiceNote ExportJobCommand = "create_voice_note"
)

type ExportBlockJob interface {
	BlockJob
}

type ExportJobConfig struct {
	Command ExportJobCommand `json:"command" validate:"required"`
}

type exportBlockJob struct {
	blockJob
}

func NewExportBlockJob(r *models.Record, app core.App) (ExportBlockJob, error) {
	if BlockJobType(r.GetString(BlockJobFieldType)) != BlockJobTypeExport {
		slog.Error("Not an export job", slog.String("type", r.GetString(BlockJobFieldType)))
		return nil, fmt.Errorf("Not an export job: %s", r.GetString(BlockJobFieldType))
	}

	var config ExportJobConfig
	err := r.UnmarshalJSONField(BlockJobFieldConfig, &config)
	if err != nil {
		slog.Error("Error unmarshalling export job config", "err", err)
		return nil, err
	}

	switch config.Command {
	case ExportJobCommandCreateVoiceNote:
		return NewCreateVoiceNoteJob(r, app)
	default:
		return nil, fmt.Errorf("Unknown export job command: %s", config.Command)
	}
}

type NewExportBlockJobFormConfig struct {
	Collection *models.Collection
	App        core.App
	BlockId    string
	UserId     string
}

// ----------------------------
// Create Voice Note export job
// ----------------------------

type CreateVoiceNoteJobConfig struct {
	Command ExportJobCommand             `json:"command" validate:"eq=create_voice_note"`
	Data    CreateVoiceNoteJobConfigData `json:"data" validate:"required"`
}

type CreateVoiceNoteJobConfigData struct {
	InternalBlockId string                `json:"internal_block_id" validate:"required"`
	DestinationId   string                `json:"destination_id" validate:"required"`
	Files           []CreateVoiceNoteFile `json:"files" validate:"required"`
}

type CreateVoiceNoteFile struct {
	Path string
	Name string
}

type CreateVoiceNoteJob interface {
	ExportBlockJob

	ConfigData() (*CreateVoiceNoteJobConfigData, error)
	SetConfigData(data *CreateVoiceNoteJobConfigData) error
}

type createVoiceNoteJob struct {
	exportBlockJob
}

func NewCreateVoiceNoteJob(r *models.Record, app core.App) (CreateVoiceNoteJob, error) {
	// Validate is export job
	if BlockJobType(r.GetString(BlockJobFieldType)) != BlockJobTypeExport {
		return nil, fmt.Errorf("Not an export job: %s", r.GetString(BlockJobFieldType))
	}

	// Validate is create voice note job
	var config ExportJobConfig
	err := r.UnmarshalJSONField(BlockJobFieldConfig, &config)
	if err != nil {
		slog.Error("Error unmarshalling export job config", "err", err)
		return nil, err
	}
	if config.Command != ExportJobCommandCreateVoiceNote {
		return nil, fmt.Errorf("Not a create voice note job: %s", config.Command)
	}

	return &createVoiceNoteJob{
		exportBlockJob: exportBlockJob{
			blockJob: blockJob{
				record: r,
				app:    app,
			},
		},
	}, nil
}

func (j *createVoiceNoteJob) ConfigData() (*CreateVoiceNoteJobConfigData, error) {
	var config CreateVoiceNoteJobConfig
	err := j.record.UnmarshalJSONField(BlockJobFieldConfig, &config)
	if err != nil {
		slog.Error("Error unmarshalling create voice note job config", "err", err)
		return nil, err
	}

	err = validate.Struct(config)
	if err != nil {
		slog.Error("Error validating create voice note job config", "err", err)
		return nil, err
	}

	return &config.Data, nil
}

func (j *createVoiceNoteJob) SetConfigData(data *CreateVoiceNoteJobConfigData) error {
	config := CreateVoiceNoteJobConfig{
		Command: ExportJobCommandCreateVoiceNote,
		Data:    *data,
	}

	err := validate.Struct(config)
	if err != nil {
		slog.Error("Error validating create voice note job config", "err", err)
		return err
	}

	json, err := json.Marshal(config)
	if err != nil {
		slog.Error("Error marshalling create voice note job config", "err", err)
		return err
	}
	j.record.Set(BlockJobFieldConfig, json)
	return nil
}
