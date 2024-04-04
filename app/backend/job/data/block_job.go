package data

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionBlockJob = "block_job"

	BlockJobFieldStatus    = "status"
	BlockJobFieldBlock     = "block"
	BlockJobFieldType      = "type"
	BlockJobFieldNextRunAt = "next_run_at"
	BlockJobFieldUser      = "user"
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
	Block() string
	User() string
	Record() *models.Record
	NextRunAt() types.DateTime
}

func LoadBlockJob(r *models.Record) BlockJob {
	return &blockJob{
		record: r,
	}
}

type NewExportBlockJobFormConfig struct {
	Collection *models.Collection
	App        core.App
	BlockId    string
	UserId     string
}

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

type blockJob struct {
	record *models.Record
}

func (j *blockJob) ID() string {
	return j.record.Id
}

func (j *blockJob) Status() BlockJobStatus {
	return BlockJobStatus(j.record.GetString(BlockJobFieldStatus))
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

func (j *blockJob) NextRunAt() types.DateTime {
	return j.record.GetDateTime(BlockJobFieldNextRunAt)
}
