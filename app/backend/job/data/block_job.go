package data

import (
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionBlockJob      = "block_job"
	BlockJobFieldType       = "type"
	BlockJobFieldStatus     = "status"
	BlockJobFieldSummary    = "summary"
	BlockJobFieldBlock      = "block"
	BlockJobFieldUser       = "user"
	BlockJobFieldNextRunAt  = "next_run_at"
	BlockJobFieldErrorCount = "error_count"
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
	ID() string
	Type() BlockJobType
	Status() BlockJobStatus
	Summary() string
	Block() string
	User() string
	NextRunAt() time.Time
	ErrorCount() int

	Record() *models.Record

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

type blockJob struct {
	record *models.Record
	app    core.App
}

func NewBlockJob(r *models.Record, app core.App) BlockJob {
	return &blockJob{
		record: r,
		app:    app,
	}
}

type NewExportBlockJobFormConfig struct {
	Collection *models.Collection
	App        core.App
	BlockId    string
	UserId     string
}

// Creates a new export block job initialised to now and waiting status.
func NewExportBlockJobForm(config NewExportBlockJobFormConfig) (*forms.RecordUpsert, error) {
	record := models.NewRecord(config.Collection)
	form := forms.NewRecordUpsert(config.App, record)

	err := form.LoadData(map[string]interface{}{
		BlockJobFieldType:      BlockJobTypeExport,
		BlockJobFieldStatus:    BlockJobStatusWaiting,
		BlockJobFieldBlock:     config.BlockId,
		BlockJobFieldUser:      config.UserId,
		BlockJobFieldNextRunAt: types.NowDateTime(),
	})
	if err != nil {
		return nil, err
	}

	return form, nil
}

func (j *blockJob) ID() string {
	return j.record.Id
}

func (j *blockJob) Status() BlockJobStatus {
	return BlockJobStatus(j.record.GetString(BlockJobFieldStatus))
}

func (j *blockJob) Summary() string {
	return j.record.GetString(BlockJobFieldSummary)
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
