package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"time"

	_ "exnota.com/backend/migrations"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
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
	COLLECTION_USER = "users"

	COLLECTION_BLOCK  = "block"
	BLOCK_FIELD_TYPE  = "type"
	BLOCK_FIELD_USER  = "user"
	BLOCK_FIELD_TITLE = "title"
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

// TODO: Update hooks to target collections where relevant, e.g.:
//
//	app.OnRecordBeforeCreateRequest("users", "articles")
func bindAppHooks(app core.App) {
	// serves static files from the provided public dir (if exists)
	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET("/*", apis.StaticDirectoryHandler(os.DirFS("./pb_public"), false))
		return nil
	})

	// initJobWorker(app)
	bindJobCreatorHooks(app)
	bindUnauthenticatedHooks(app)
	bindBlockInvariantsHooks(app)
}

func bindUnauthenticatedHooks(app core.App) {
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

	app.OnRecordBeforeDeleteRequest().Add(func(e *core.RecordDeleteEvent) error {
		requestInfo := apis.RequestInfo(e.HttpContext)
		if requestInfo.AuthRecord == nil && requestInfo.Admin == nil {
			return apis.NewUnauthorizedError("Not logged in", nil)
		}
		return nil
	})
}

func bindBlockInvariantsHooks(app core.App) {
	// type cannot be changed
	app.OnRecordBeforeUpdateRequest().Add(func(e *core.RecordUpdateEvent) error {
		if e.Record.Collection().Name != COLLECTION_BLOCK {
			return nil
		}

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
	app.OnRecordBeforeUpdateRequest().Add(func(e *core.RecordUpdateEvent) error {
		if e.Record.Collection().Name != COLLECTION_BLOCK {
			return nil
		}

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
}

const JOB_CREATOR_WORKER = "job_creator_worker"

type JobCreatorJob struct {
	BlockId      string
	UpdatedTitle string
}

// TODO: First, perhaps check that I can call transcriptions from a job.
// 1. Maybe deploy a hardcoded audio file and after some hook fires (doesn't matter
// which for testing purposes), try to execute whisper on it.
// 2. Then maybe deploy and try to get it working in prod.
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
