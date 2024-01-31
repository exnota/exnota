package record

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
)

type BlockJob interface {
	ID() string
	Type() JobType
	Status() JobStatus
	Block() string
	User() string
	Record() *models.Record
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

	err := form.LoadData(map[string]any{
		"type":   Export.String(),
		"status": Waiting.String(),
		"block":  config.BlockId,
		"user":   config.UserId,
	})
	if err != nil {
		return nil, err
	}

	return form, nil
}

type JobStatus int

const (
	Waiting JobStatus = iota
	Running
	Error
	Complete
)

func (s JobStatus) String() string {
	switch s {
	case Waiting:
		return "waiting"
	case Running:
		return "running"
	case Error:
		return "error"
	case Complete:
		return "complete"
	default:
		panic("unknown status")
	}
}

type JobType int

const (
	Transcription JobType = iota
	Export
)

func (t JobType) String() string {
	switch t {
	case Transcription:
		return "transcription"
	case Export:
		return "export"
	default:
		panic("unknown type")
	}
}

type blockJob struct {
	record *models.Record
}

func (j *blockJob) ID() string {
	return j.record.Id
}

func (j *blockJob) Status() JobStatus {
	switch j.record.GetString("status") {
	case "waiting":
		return Waiting
	case "running":
		return Running
	case "error":
		return Error
	case "complete":
		return Complete
	default:
		panic("unknown status")
	}
}

func (j *blockJob) Type() JobType {
	switch j.record.GetString("type") {
	case "transcription":
		return Transcription
	case "export":
		return Export
	default:
		panic("unknown type")
	}
}

func (j *blockJob) Record() *models.Record {
	return j.record
}

func (j *blockJob) Block() string {
	return j.record.GetString("block")
}

func (j *blockJob) User() string {
	return j.record.GetString("user")
}
