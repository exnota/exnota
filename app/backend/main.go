package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"time"

	_ "exnota.com/backend/migrations"
	validation "github.com/go-ozzo/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms/validators"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/cron"
)

func main() {
	app := pocketbase.New()

	autoMigrate := isAutoMigrate()
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		// enable auto creation of migration files when making collection changes in the Admin UI
		// (the isGoRun check is to enable it only during development)
		Automigrate: autoMigrate,
	})

	bindAppHooks(app)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

const (
	COLLECTION_USER = "user"

	COLLECTION_BLOCK  = "block"
	BLOCK_FIELD_TYPE  = "type"
	BLOCK_FIELD_USER  = "user"
	BLOCK_FIELD_TITLE = "title"
	BLOCK_FIELD_FILE  = "file"

	COLLECTION_BLOCK_JOB  = "block_job"
	BLOCK_JOB_FIELD_TYPE  = "type"
	BLOCK_JOB_FIELD_USER  = "user"
	BLOCK_JOB_FIELD_BLOCK = "block"
)

func isAutoMigrate() bool {
	isGoRun := strings.HasPrefix(os.Args[0], os.TempDir())
	isVsCodeDebug := strings.HasPrefix(os.Args[0], "/workspaces/exnota/app/backend")
	autoMigrate := isGoRun || isVsCodeDebug
	if autoMigrate {
		fmt.Println("Automigrations on")
	} else {
		fmt.Println("Automigrations off")
	}
	return autoMigrate
}

func bindAppHooks(app core.App) {
	// serves static files from the provided public dir (if exists)
	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET("/*", apis.StaticDirectoryHandler(os.DirFS("./pb_public"), false))
		return nil
	})

	// initJobWorker(app)
	// bindJobCreatorHooks(app)
	setGlobalDeleteRules(app)
	setGlobalAuthenticationRules(app)
	setBlockInvariants(app)
	setBlockJobInvariants(app)
}

func setGlobalDeleteRules(app core.App) {
	// deleting not allowed on any collection
	app.OnRecordBeforeDeleteRequest().Add(func(e *core.RecordDeleteEvent) error {
		return NewMethodNotAllowedError("Cannot delete", nil)
	})
}

func setGlobalAuthenticationRules(app core.App) {
	app.OnRecordsListRequest().Add(func(e *core.RecordsListEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})
	app.OnRecordViewRequest().Add(func(e *core.RecordViewEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})

	app.OnRecordBeforeCreateRequest().Add(func(e *core.RecordCreateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})

	app.OnRecordBeforeUpdateRequest().Add(func(e *core.RecordUpdateEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})
}

func setBlockInvariants(app core.App) {
	// type cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newType := e.Record.GetString(BLOCK_FIELD_TYPE)

		if newType != existingRecord.GetString(BLOCK_FIELD_TYPE) {
			return apis.NewBadRequestError("Cannot change block type", nil)
		}

		return nil
	})

	// user cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newUserId := e.Record.GetString(BLOCK_FIELD_USER)

		if newUserId != existingRecord.GetString(BLOCK_FIELD_USER) {
			return apis.NewBadRequestError("Cannot change block user", nil)
		}

		return nil
	})

	// file creation
	app.OnRecordBeforeCreateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordCreateEvent) error {
		newType := e.Record.GetString(BLOCK_FIELD_TYPE)

		// audio block must have a file
		if newType == "audio" {
			files := e.UploadedFiles[BLOCK_FIELD_FILE]
			if len(files) != 1 {
				return apis.NewBadRequestError("Audio block must have exactly 1 file", nil)
			}

			// Content types supported by Pocketbase: https://github.com/gabriel-vasile/mimetype/blob/master/supported_mimes.md
			if err := validators.UploadedFileMimeType([]string{"audio/wav", "audio/mpeg"})(files[0]); err != nil {
				// Verify it's a mime type error, because if we simply return
				// the err object the error message will be a generic
				// "Something went wrong while processing your request."
				errObj := err.(validation.ErrorObject)
				if errObj.Code() == "validation_invalid_mime_type" {
					return apis.NewBadRequestError("Audio block must have a .wav or .mp3 file.", nil)
				}
				return err
			}
		} else {
			files := e.UploadedFiles[BLOCK_FIELD_FILE]
			if len(files) != 0 {
				return apis.NewBadRequestError("Non-audio block cannot have a file", nil)
			}
		}

		return nil
	})

	// file cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newFile := e.Record.Get(BLOCK_FIELD_FILE)

		if newFile != existingRecord.Get(BLOCK_FIELD_FILE) {
			return apis.NewBadRequestError("Cannot change block file", nil)
		}

		return nil
	})

}

func setBlockJobInvariants(app core.App) {
	// type cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newType := e.Record.GetString(BLOCK_JOB_FIELD_TYPE)

		if newType != existingRecord.GetString(BLOCK_JOB_FIELD_TYPE) {
			return apis.NewBadRequestError("Cannot change block job type", nil)
		}

		return nil
	})

	// user cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newUserId := e.Record.GetString(BLOCK_JOB_FIELD_USER)

		if newUserId != existingRecord.GetString(BLOCK_JOB_FIELD_USER) {
			return apis.NewBadRequestError("Cannot change block job user", nil)
		}

		return nil
	})

	// block cannot be changed
	app.OnRecordBeforeUpdateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordUpdateEvent) error {
		existingRecord, err := app.Dao().FindRecordById(e.Record.Collection().Id, e.Record.Id, nil)
		if err != nil {
			return err
		}

		newBlockId := e.Record.GetString(BLOCK_JOB_FIELD_BLOCK)

		if newBlockId != existingRecord.GetString(BLOCK_JOB_FIELD_BLOCK) {
			return apis.NewBadRequestError("Cannot change block job block", nil)
		}

		return nil
	})

	// user must match block's user
	app.OnRecordBeforeCreateRequest(COLLECTION_BLOCK_JOB).Add(func(e *core.RecordCreateEvent) error {
		blockId := e.Record.GetString(BLOCK_JOB_FIELD_BLOCK)
		block, err := app.Dao().FindRecordById(COLLECTION_BLOCK, blockId, nil)
		if err != nil {
			return err
		}

		blockUserId := block.GetString(BLOCK_FIELD_USER)
		jobUserId := e.Record.GetString(BLOCK_JOB_FIELD_USER)

		if blockUserId != jobUserId {
			return apis.NewBadRequestError("Block job user must match block user", nil)
		}

		return nil
	})
}

const JOB_CREATOR_WORKER = "job_creator_worker"

type JobCreatorJob struct {
	BlockId      string
	UpdatedTitle string
}

// TODO: First, perhaps check that I can call transcriptions from a job.
// 1. Maybe deploy a hardcoded audio file and after some hook fires (doesn't matter
// which for testing purposes), try to execute whisper on it.
// 2. Then maybe try in prod
//
// TODO: Maybe to improve what's below... the job's work can be triggered by
// a hook on the job collection itself. Then that job collection hook can
// essentially function as a service that processes jobs. E.g.
// 1. After block is created, create a job of type transcription
// 2. after-create-model-job-collection hook fires
// 3. it sees it's a transcription job and starts a worker
// 4. i suppose that worker still needs to update the job status itself, rather
// than immediately doing it in the hook, in case there is a queue and the job
// worker isn't actually started yet.
// 5. the worker sets to complete later
// 6. after-update-model-job-collection hook fires, notices it's a transcription
// job that completed, so it creates a new job of type export
// 7. after-create-model-job-collection hook fires, notices it's an export job
// and starts worker. Once the worker starts that updates the job status.
//
// TODO: Maybe have an initiated_by_id field on the job, so there's a clear trace
// for which transcription job triggered the export job, etc.
//
// TODO: flow
//  1. After create audio block hook fires (which should all have a file)
//  2. Then persist a transcription job and pass it to the jobs channel
//  3. (LATER: what if there are more jobs than workers? How do I handle that?)
//  4. Worker sets the job to running
//  5. Worker starts a transaction that
//     a. Gets the file from the block
//     b. Performs the transcription (IN V0 JUST sleep for 20 seconds)
//     c. Saves the transcription to the block
//  6. Worker sets the job to finished
//  7. If any error happens in the worker, it should set the job to errored.
//  8. In an after update hook for the job collection, if the job changed from
//     not complete to complete (can get old value via: old := record.OriginalCopy())
//  9. Then create an export job and pass it to an export jobs channel
//  10. Repeat the above but for exporting to Notion.
//  11. TODO: Question: Same job collection for all jobs? Or separate ones?
//
// Possibly: When server starts up, check for any 'running' jobs and retry them.
//
// TODO: work
//
//  1. Create new json field called 'audio' as JSON, which has 'file'
//     and 'transcription' keys. 'transcription' is an array of strings.
//
//  2. Create job collections, unsure if should be the same collection or not.
//     Perhaps mock it out as though it's the same and see if there are issues.
//     Would just need a 'type' field on the job.
func jobCreatorWorker(id int, jobs <-chan JobCreatorJob, results chan<- string, app core.App) {
	for j := range jobs {
		fmt.Println("worker", id, "started job", j)
		time.Sleep(20 * time.Second)
		// TODO: This is currently an infinite loop as modifying the block triggers the hook again.
		err := app.Dao().RunInTransaction(func(txDao *daos.Dao) error {
			block, err := txDao.FindRecordById(COLLECTION_BLOCK, j.BlockId, nil)
			if err != nil {
				// TODO: Handle this somehow
				fmt.Println("worker", id, "error", err)
				return err
			}

			// Add an 'x' to the end to simulate updating some info
			block.Set(BLOCK_FIELD_TITLE, block.GetString(BLOCK_FIELD_TITLE)+"x")
			err = txDao.SaveRecord(block)
			if err != nil {
				// TODO: Handle this somehow
				fmt.Println("worker", id, "error", err)
				return err
			}

			// results <- "done"
			return nil
		})
		if err != nil {
			// TODO: Handle this somehow
			fmt.Println("worker", id, "error", err)
		}
		fmt.Println("worker", id, "finished job", j)
	}
}

func bindJobCreatorHooks(app core.App) {
	jobs := make(chan JobCreatorJob)
	results := make(chan string)

	for w := 1; w <= 2; w++ {
		go jobCreatorWorker(w, jobs, results, app)
	}

	app.OnModelAfterCreate(COLLECTION_BLOCK).Add(func(e *core.ModelEvent) error {
		record := e.Model.(*models.Record)
		title := record.GetString(BLOCK_FIELD_TITLE)
		jobs <- JobCreatorJob{
			BlockId:      record.Id,
			UpdatedTitle: title,
		}

		// TODO: Create job and initiate worker
		// Worker: Sets to running, performs, sets to finished.

		return nil
	})
	app.OnModelAfterUpdate(COLLECTION_BLOCK).Add(func(e *core.ModelEvent) error {
		record := e.Model.(*models.Record)
		title := record.GetString(BLOCK_FIELD_TITLE)
		jobs <- JobCreatorJob{
			BlockId:      record.Id,
			UpdatedTitle: title,
		}
		return nil
	})
}

const SCHEDULER_JOB_WORKER = "job_worker"

func jobWorker(id int, jobs <-chan int, results chan<- int) {
	for j := range jobs {
		fmt.Println("worker", id, "started  job", j)
		time.Sleep(time.Second)
		fmt.Println("worker", id, "finished job", j)
		results <- j * 2
	}
}

func initJobWorker(app core.App) {
	jobs := make(chan int)
	results := make(chan int)

	for w := 1; w <= 3; w++ {
		go jobWorker(w, jobs, results)
	}

	// for j := 1; j <= numJobs; j++ {
	//     jobs <- j
	// }
	// close(jobs)

	// TODO: DO i need to do anything with results? Do i need results? Maybe for logging?
	// for a := 1; a <= numJobs; a++ {
	//     <-results
	// }

	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		scheduler := cron.New()

		// Can probably do this at an even higher frequency with time.Tick
		// timer suggestion: https://github.com/pocketbase/pocketbase/discussions/2101#discussioncomment-5371500
		// another timer suggestion https://github.com/pocketbase/pocketbase/discussions/3535
		scheduler.MustAdd(SCHEDULER_JOB_WORKER, "* * * * *", func() {
			// log.Println("Hello!")
			// TODO: How well does this handle multiple jobs at once?
			// TODO: Can I get dao data here?
			// TODO: Could I move and refactor this into a post-update hook rather
			// than solely re-pinging the database? The hook could create the DB entry as it starts...
			// but would still probably need something like this periodically for jobs that didn't finish.
			jobs <- rand.Intn(100)
		})

		scheduler.Start()

		return nil
	})
}
