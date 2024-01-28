// main_test.go
package main

import (
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tokens"
)

const testDataDir = "./pb_data_test"

type RequestScenario struct {
	Name   string
	Method string
	Url    string

	// Only one of these should be set
	BodyStr           string
	BlockBodyWithFile *BlockWithFile

	TestAppFactory func(t *testing.T) *tests.TestApp
	AuthScenarios  []AuthScenario
}

type AuthScenario struct {
	Name            string
	RequestHeaders  map[string]string
	ExpectedStatus  int
	ExpectedContent []string
	ExpectedEvents  map[string]int
}

type BlockType string

const (
	BlockTypeAudio BlockType = "audio"
	BlockTypeText  BlockType = "text"
)

type BlockWithFile struct {
	Type  BlockType
	Title string
	User  string
}

type Tokens struct {
	Admin   string
	UserOne string
	UserTwo string
}

func TestAppHooks(t *testing.T) {
	userOneToken, err := generateRecordToken("user", "user1@example.com")
	if err != nil {
		t.Fatal(err)
	}

	userTwoToken, err := generateRecordToken("user", "user2@example.com")
	if err != nil {
		t.Fatal(err)
	}

	adminToken, err := generateAdminToken("admin@example.com")
	if err != nil {
		t.Fatal(err)
	}

	tokens := Tokens{
		Admin:   adminToken,
		UserOne: userOneToken,
		UserTwo: userTwoToken,
	}

	// setup the test ApiScenario app instance
	setupTestApp := func(t *testing.T) *tests.TestApp {
		testApp, err := tests.NewTestApp(testDataDir)
		if err != nil {
			t.Fatal(err)
		}
		// no need to cleanup since scenario.Test() will do that for us
		// defer testApp.Cleanup()

		bindAppHooks(testApp)

		return testApp
	}

	// Tips:
	//
	// Docs: docs/backend/test.md
	//
	// IDs can be found in tool/test-seed/index.ts
	//
	// To populate ExpectedContent:
	// 1. When test fails, check that the actual ExpectedContent value is expected.
	// 2. Copy it to this site and press 'Escape JSON': https://www.freeformatter.com/json-escape.html
	// 3. Paste result inside quotes in the scenario, like: []string{"<paste here>"}
	//
	// Some example API tests in Pocketbase repo: https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/apis/record_crud_test.go
	var requestScenarios []RequestScenario
	requestScenarios = append(requestScenarios, generateBlockAuthScenarios(setupTestApp, tokens)...)
	requestScenarios = append(requestScenarios, generateBlockInvariantScenarios(setupTestApp, tokens)...)
	requestScenarios = append(requestScenarios, generateBlockJobInvariantScenarios(setupTestApp, tokens)...)

	for _, scenario := range requestScenarios {
		for _, authScenario := range scenario.AuthScenarios {

			var body io.Reader = nil
			var requestHeaders map[string]string = authScenario.RequestHeaders
			// The multipart data needs to be generated separately for each
			// scenario. Re-using the same objects across scenarios causes an
			// error.
			if scenario.BlockBodyWithFile != nil {
				formData, mp, err := tests.MockMultipartData(map[string]string{
					"title": scenario.BlockBodyWithFile.Title,
					"type":  string(scenario.BlockBodyWithFile.Type),
					"user":  scenario.BlockBodyWithFile.User,
				}, "file")
				if err != nil {
					panic(err)
				}
				body = formData
				if requestHeaders == nil {
					requestHeaders = make(map[string]string)
				}
				requestHeaders["Content-Type"] = mp.FormDataContentType()
			} else {
				body = strings.NewReader(scenario.BodyStr)
			}

			apiScenario := tests.ApiScenario{
				Name:            scenario.Name + ": " + authScenario.Name,
				Method:          scenario.Method,
				Url:             scenario.Url,
				RequestHeaders:  requestHeaders,
				Body:            body,
				ExpectedStatus:  authScenario.ExpectedStatus,
				ExpectedContent: authScenario.ExpectedContent,
				ExpectedEvents:  authScenario.ExpectedEvents,
				TestAppFactory:  scenario.TestAppFactory,
			}
			apiScenario.Test(t)
		}
	}
}

func generateBlockAuthScenarios(setupTestApp func(t *testing.T) *tests.TestApp, tokens Tokens) []RequestScenario {
	return []RequestScenario{
		{
			Name:           "List blocks",
			Method:         http.MethodGet,
			Url:            "/api/collections/lrffu3q1yweoljo/records",
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name:            "Unauthenticated user",
					ExpectedStatus:  401,
					ExpectedContent: []string{"\"data\":{}"},
					ExpectedEvents: map[string]int{
						"OnRecordsListRequest": 1,
					},
				},
				{
					Name: "User one",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  200,
					ExpectedContent: []string{"\"totalItems\":10"},
					ExpectedEvents: map[string]int{
						"OnRecordsListRequest": 1,
					},
				},
				{
					Name: "User two",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserTwo,
					},
					ExpectedStatus:  200,
					ExpectedContent: []string{"\"totalItems\":2"},
					ExpectedEvents: map[string]int{
						"OnRecordsListRequest": 1,
					},
				},
			},
		},
		{
			Name:           "View block",
			Method:         http.MethodGet,
			Url:            "/api/collections/lrffu3q1yweoljo/records/block1--15chars",
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Unauthenticated user",
					// This is a 404 instead of a 401 because, I think, the API rule
					// that requires the block user to match logged in user is applied
					// as part of the database query, which then returns no results.
					// And this takes place before the on record view hook is called.
					// See https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/apis/record_crud.go#L129-L131
					ExpectedStatus:  404,
					ExpectedContent: []string{"\"data\":{}"},
				},
				{
					Name: "Block owner",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  200,
					ExpectedContent: []string{"\"id\":\"block1--15chars\""},
					ExpectedEvents: map[string]int{
						"OnRecordViewRequest": 1,
					},
				},
				{
					Name: "Non-block owner",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserTwo,
					},
					ExpectedStatus:  404,
					ExpectedContent: []string{"\"data\":{}"},
				},
			},
		},
		{
			Name:   "Create text block",
			Method: http.MethodPost,
			Url:    "/api/collections/lrffu3q1yweoljo/records",
			BodyStr: `{
				"title":"test123",
				"type":"text",
				"user":"user1-15char-id"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name:            "Unauthenticated user",
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}"},
				},
				{
					Name: "User creating for self",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  200,
					ExpectedContent: []string{"\"title\":\"test123\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeCreateRequest": 1,
						"OnRecordAfterCreateRequest":  1,
						"OnModelBeforeCreate":         1,
						"OnModelAfterCreate":          1,
					},
				},
				{
					Name: "User creating for other",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserTwo,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}"},
				},
			},
		},
		{
			Name:   "Create audio block",
			Method: http.MethodPost,
			Url:    "/api/collections/lrffu3q1yweoljo/records",
			BlockBodyWithFile: &BlockWithFile{
				Title: "test123",
				Type:  BlockTypeAudio,
				User:  "user1-15char-id",
			},
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name:            "Unauthenticated user",
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}"},
				},
				{
					Name: "User creating for self",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  200,
					ExpectedContent: []string{"\"title\":\"test123\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeCreateRequest": 1,
						"OnRecordAfterCreateRequest":  1,
						"OnModelBeforeCreate":         1,
						"OnModelAfterCreate":          1,
					},
				},
				{
					Name: "User creating for other",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserTwo,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}"},
				},
			},
		},
		{
			Name:   "Update block",
			Method: http.MethodPatch,
			Url:    "/api/collections/lrffu3q1yweoljo/records/block1--15chars",
			BodyStr: `{
				"title":"updated title"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Unauthenticated user",
					// This is a 404 instead of a 401 because, I think, the API rule
					// that requires the block user to match logged in user is applied
					// as part of the database query, which then returns no results.
					// And this takes place before the on record view hook is called.
					// See https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/apis/record_crud.go#L129-L131
					ExpectedStatus:  404,
					ExpectedContent: []string{"\"data\":{}"},
				},
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  200,
					ExpectedContent: []string{"\"title\":\"updated title\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
						"OnRecordAfterUpdateRequest":  1,
						"OnModelBeforeUpdate":         1,
						"OnModelAfterUpdate":          1,
					},
				},
				{
					Name: "User updating another's",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserTwo,
					},
					// This is a 404 instead of a 401 because, I think, the API rule
					// that requires the block user to match logged in user is applied
					// as part of the database query, which then returns no results.
					// And this takes place before the on record view hook is called.
					// See https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/apis/record_crud.go#L129-L131
					ExpectedStatus:  404,
					ExpectedContent: []string{"\"data\":{}"},
				},
			},
		},
		{
			Name:           "Delete block",
			Method:         http.MethodDelete,
			Url:            "/api/collections/lrffu3q1yweoljo/records/block1--15chars",
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Unauthenticated user",
					// This is a 404 instead of a 401 because, I think, the API rule
					// that requires the block user to match logged in user is applied
					// as part of the database query, which then returns no results.
					// And this takes place before the on record view hook is called.
					// See https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/apis/record_crud.go#L129-L131
					ExpectedStatus:  404,
					ExpectedContent: []string{"\"data\":{}"},
				},
				{
					Name: "User deleting own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  405,
					ExpectedContent: []string{"\"data\":{}"},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeDeleteRequest": 1,
					},
				},
				{
					Name: "Admin deleting",
					RequestHeaders: map[string]string{
						"Authorization": tokens.Admin,
					},
					ExpectedStatus:  405,
					ExpectedContent: []string{"\"data\":{}"},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeDeleteRequest": 1,
					},
				},
			},
		},
	}
}

func generateBlockInvariantScenarios(setupTestApp func(t *testing.T) *tests.TestApp, tokens Tokens) []RequestScenario {
	return []RequestScenario{
		{
			Name:   "Block invariant > Cannot update type",
			Method: http.MethodPatch,
			Url:    "/api/collections/lrffu3q1yweoljo/records/block1--15chars",
			BodyStr: `{
				"type":"audio"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Cannot change block type.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
					},
				},
			},
		},
		{
			Name:   "Block invariant > Cannot update user",
			Method: http.MethodPatch,
			Url:    "/api/collections/lrffu3q1yweoljo/records/block1--15chars",
			BodyStr: `{
				"user":"user2-15char-id"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Cannot change block user.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
					},
				},
			},
		},
		{
			Name:   "Block invariant > Audio type requires file",
			Method: http.MethodPost,
			Url:    "/api/collections/lrffu3q1yweoljo/records",
			BodyStr: `{
				"title":"test123",
				"type":"audio",
				"user":"user1-15char-id"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Audio block must have a file.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeCreateRequest": 1,
					},
				},
			},
		},
		{
			Name:   "Block invariant > Non-audio type cannot have a file",
			Method: http.MethodPost,
			Url:    "/api/collections/lrffu3q1yweoljo/records",
			BlockBodyWithFile: &BlockWithFile{
				Title: "test123",
				Type:  BlockTypeText,
				User:  "user1-15char-id",
			},
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Non-audio block cannot have a file.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeCreateRequest": 1,
					},
				},
			},
		},
		{
			Name:   "Block invariant > Cannot update file",
			Method: http.MethodPatch,
			Url:    "/api/collections/lrffu3q1yweoljo/records/block10-15chars",
			BlockBodyWithFile: &BlockWithFile{
				Type:  BlockTypeAudio,
				User:  "user1-15char-id",
				Title: "test123",
			},
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Admin updating",
					RequestHeaders: map[string]string{
						"Authorization": tokens.Admin,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Cannot change block file.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
					},
				},
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Cannot change block file.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
					},
				},
			},
		},
	}
}

func generateBlockJobInvariantScenarios(setupTestApp func(t *testing.T) *tests.TestApp, tokens Tokens) []RequestScenario {
	return []RequestScenario{
		{
			Name:   "Block job invariant > Cannot update type",
			Method: http.MethodPatch,
			Url:    "/api/collections/cml7ayp8msc7q1w/records/block01-job---1",
			BodyStr: `{
				"type":"export"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Admin updating",
					RequestHeaders: map[string]string{
						"Authorization": tokens.Admin,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Cannot change block job type.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
					},
				},
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  403,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Only admins can perform this action.\""},
				},
			},
		},
		{
			Name:   "Block job invariant > Cannot update user",
			Method: http.MethodPatch,
			Url:    "/api/collections/cml7ayp8msc7q1w/records/block01-job---1",
			BodyStr: `{
				"user":"user2-15char-id"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Admin updating",
					RequestHeaders: map[string]string{
						"Authorization": tokens.Admin,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Cannot change block job user.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
					},
				},
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  403,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Only admins can perform this action.\""},
				},
			},
		},
		{
			Name:   "Block job invariant > Cannot update block",
			Method: http.MethodPatch,
			Url:    "/api/collections/cml7ayp8msc7q1w/records/block01-job---1",
			BodyStr: `{
				"block":"block2--15chars"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Admin updating",
					RequestHeaders: map[string]string{
						"Authorization": tokens.Admin,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Cannot change block job block.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeUpdateRequest": 1,
					},
				},
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  403,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Only admins can perform this action.\""},
				},
			},
		},
		{
			Name:   "Block job invariant > User must match block's user",
			Url:    "/api/collections/cml7ayp8msc7q1w/records",
			Method: http.MethodPost,
			BodyStr: `{
				"type": "transcription",
				"status": "waiting",
				"summary": [],
				"block": "block2--15chars",
				"user": "user2-15char-id"
			}`,
			TestAppFactory: setupTestApp,
			AuthScenarios: []AuthScenario{
				{
					Name: "Admin updating",
					RequestHeaders: map[string]string{
						"Authorization": tokens.Admin,
					},
					ExpectedStatus:  400,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Block job user must match block user.\""},
					ExpectedEvents: map[string]int{
						"OnRecordBeforeCreateRequest": 1,
					},
				},
				{
					Name: "User updating own",
					RequestHeaders: map[string]string{
						"Authorization": tokens.UserOne,
					},
					ExpectedStatus:  403,
					ExpectedContent: []string{"\"data\":{}", "\"message\":\"Only admins can perform this action.\""},
				},
			},
		},
	}
}

func generateAdminToken(email string) (string, error) {
	app, err := tests.NewTestApp(testDataDir)
	if err != nil {
		return "", err
	}
	defer app.Cleanup()

	admin, err := app.Dao().FindAdminByEmail(email)
	if err != nil {
		return "", err
	}

	return tokens.NewAdminAuthToken(app, admin)
}

func generateRecordToken(collectionNameOrId string, email string) (string, error) {
	app, err := tests.NewTestApp(testDataDir)
	if err != nil {
		return "", err
	}
	defer app.Cleanup()

	record, err := app.Dao().FindAuthRecordByEmail(collectionNameOrId, email)
	if err != nil {
		return "", err
	}

	return tokens.NewRecordAuthToken(app, record)
}
