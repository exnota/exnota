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
	Summary() (map[string]interface{}, error)
	Block() string
	User() string
	NextRunAt() time.Time
	ErrorCount() int

	SetType(t BlockJobType)
	SetStatus(status BlockJobStatus)
	SetSummary(summary Summary) error
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
		return LoadExportBlockJob(r, app)
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

func (j *blockJob) Summary() (map[string]interface{}, error) {
	result := make(map[string]interface{})
	err := j.record.UnmarshalJSONField(BlockJobFieldSummary, result)
	if err != nil {
		slog.Error("Error unmarshalling block job summary", "err", err)
		return nil, err
	}
	return result, nil
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

type Summary interface {
	AsMap() map[string]interface{}
}

type summaryComplete struct {
	message string
}

func NewSummaryComplete(message string) Summary {
	return summaryComplete{
		message: message,
	}
}
func NewSummaryCompleteEmpty() Summary {
	return summaryComplete{}
}
func (s summaryComplete) AsMap() map[string]interface{} {
	return map[string]interface{}{
		"message": s.message,
	}
}

type summaryError struct {
	error error
}

func NewSummaryError(err error) Summary {
	return summaryError{
		error: err,
	}
}
func (s summaryError) AsMap() map[string]interface{} {
	return map[string]interface{}{
		"error": s.error.Error(),
	}
}

func (j *blockJob) SetSummary(summary Summary) error {
	asMap := summary.AsMap()
	asMapBytes, err := json.Marshal(asMap)
	if err != nil {
		slog.Error("Error marshalling block job summary", "err", err)
		return err
	}
	j.record.Set(BlockJobFieldSummary, string(asMapBytes))
	return nil
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

	// Submit calls validate internally
	return form.Submit()
}

// ----------------------------
// Transcription Block Job
// ----------------------------

type TranscriptionBlockJob interface {
	BlockJob

	ValidateTranscription(txDao *daos.Dao) error
}

type transcriptionBlockJob struct {
	blockJob
}

func CreateTranscriptionBlockJob(app core.App) (TranscriptionBlockJob, error) {
	collection, err := app.Dao().FindCollectionByNameOrId(CollectionBlockJob)
	if err != nil {
		return nil, err
	}

	record := models.NewRecord(collection)
	record.Set(BlockJobFieldType, string(BlockJobTypeTranscription))
	return NewTranscriptionBlockJob(record, app)
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

func (j *transcriptionBlockJob) ValidateTranscription(txDao *daos.Dao) error {
	// TODO: Implement when there is transcription-specific logic
	return nil
}

// ----------------------------
// Export Block Job
// ----------------------------

type ExportJobCommand string

const (
	CommandCreateVoiceNote ExportJobCommand = "create_voice_note"
)

type ExportBlockJob interface {
	BlockJob

	Config() (ExportJobConfig, error)
	SetConfig(config ExportJobConfig) error
}

type ExportJobConfig struct {
	Command ExportJobCommand `json:"command" validate:"required"`
	Data    ExportJobData    `json:"data"    validate:"required"`
}

type ExportBlockType string

const (
	BlockTypeVoiceNote ExportBlockType = "voice-note"
	BlockTypeTextNote  ExportBlockType = "text-note"
)

type audioField struct {
	Transcription []string `json:"transcription"`
}

// This is a diff representing the changes to a block that should be exported.
type ExportJobData struct {
	Id          string          `json:"id"          validate:"required"`
	Title       *string         `json:"title"`
	Type        ExportBlockType `json:"type"        validate:"required"`
	Destination string          `json:"destination" validate:"required"`
	File        *string         `json:"file"`
	Audio       *audioField     `json:"audio"`

	// UserCreated string
	// Archived    string

	// UserProperties lib_block.UserPropertyValues
}

type exportBlockJob struct {
	blockJob
}

func CreateExportJob(app core.App) (ExportBlockJob, error) {
	collection, err := app.Dao().FindCollectionByNameOrId(CollectionBlockJob)
	if err != nil {
		return nil, err
	}

	record := models.NewRecord(collection)
	record.Set(BlockJobFieldType, string(BlockJobTypeExport))
	// Set the command so calling NewVoiceNoteJob doesn't error, but this
	// isn't a valid config without 'data'. This could be refactored.
	record.Set(BlockJobFieldConfig, &ExportJobConfig{})
	return LoadExportBlockJob(record, app)
}

func LoadExportBlockJob(r *models.Record, app core.App) (ExportBlockJob, error) {
	// Verify is export job
	if BlockJobType(r.GetString(BlockJobFieldType)) != BlockJobTypeExport {
		slog.Error("Not an export job", slog.String("type", r.GetString(BlockJobFieldType)))
		return nil, fmt.Errorf("Not an export job: %s", r.GetString(BlockJobFieldType))
	}

	job := &exportBlockJob{
		blockJob: blockJob{
			record: r,
			app:    app,
		},
	}

	// Validate config to catch errors early
	_, err := job.Config()
	if err != nil {
		return nil, err
	}

	return job, nil
}

func (j *exportBlockJob) Config() (ExportJobConfig, error) {
	var config ExportJobConfig
	err := j.record.UnmarshalJSONField(BlockJobFieldConfig, &config)
	if err != nil {
		slog.Error("Error unmarshalling export job config", "err", err)
		return ExportJobConfig{}, err
	}
	return config, nil
}

func (j *exportBlockJob) SetConfig(config ExportJobConfig) error {
	err := validate.Struct(config)
	if err != nil {
		return err
	}

	configBytes, err := json.Marshal(config)
	if err != nil {
		slog.Error("Error marshalling export job config", "err", err)
		return err
	}
	j.record.Set(BlockJobFieldConfig, string(configBytes))
	return nil
}
