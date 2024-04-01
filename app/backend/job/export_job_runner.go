package job

import (
	"errors"
	"fmt"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/tools/types"
)

type ExportJobRunner interface {
	Run() error
}

type exportJobRunnerConfig struct {
	blockJobId string
	blockId    string
	app        core.App
}

func NewExportJobRunner(blockJobId string, blockId string, app core.App) ExportJobRunner {
	return &exportJobRunnerConfig{
		blockJobId: blockJobId,
		blockId:    blockId,
		app:        app,
	}
}

// run method
func (j *exportJobRunnerConfig) Run() error {
	err := j.setJobStatus("running", true, nil)
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	time.Sleep(5 * time.Second)

	err = j.setJobStatus("complete", false, nil)
	if err != nil {
		err := j.setJobStatusError(err)
		return err
	}

	return nil
}

func (j *exportJobRunnerConfig) setJobStatusError(jobErr error) error {
	return j.setJobStatus("error", false, jobErr)
}

func (j *exportJobRunnerConfig) setJobStatus(status string, validateWaiting bool, jobErr error) error {
	err := j.app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
		blockJob, err := txDao.FindRecordById("block_job", j.blockJobId)
		if err != nil {
			return err
		}

		if validateWaiting && blockJob.GetString("status") != "waiting" {
			return errors.New("Block Job is not in waiting state")
		}

		blockJob.Set("status", status)
		if jobErr != nil {
			var summary []string

			rawField := blockJob.Get("summary").(types.JsonRaw)
			val, err := rawField.Value()
			if err != nil {
				return err
			}

			if val == nil {
				summary = []string{jobErr.Error()}
			} else {
				// TODO: There is a limit on the size of the summary field. We
				// should truncate it if it gets too big.
				err = blockJob.UnmarshalJSONField("summary", &summary)
				if err != nil {
					return err
				}
				summary = append(summary, jobErr.Error())
			}

			blockJob.Set("summary", summary)
			fmt.Println("summary", summary)
		}

		// TODO: Should this be updated to use forms.NewRecordUpsert so it has validations?
		// https://pocketbase.io/docs/go-records/#update-existing-record
		if err := txDao.SaveRecord(blockJob); err != nil {
			return err
		}
		return nil
	})
	return err
}
