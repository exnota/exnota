# Test

## Troubleshooting

* Test fails with: `Failed to load the submitted data due to invalid formatting.`
  * Can occur when re-using the Reader/Buffer passed to `Body` of `tests.ApiScenario` across multiple scenarios. Generate new objects for each scenario.

## Pocketbase integration

* Files mocked using `pocketbase/tests/request.go->MockMultipartData` are detected as "text/plain; charset=utf-8" content type ([link](https://github.com/pocketbase/pocketbase/blob/9436efb7fd8b9726715b58eb949f12a634fcafa0/forms/validators/file_test.go#L85C3-L86C74)).
* Test directory contents won't be modified. It is [cloned by the test helper](https://github.com/pocketbase/pocketbase/blob/3f7db19fdd83774dabe83337523e863773e23689/tests/app.go#L473).

## Updating test seed data

1. Delete test data `pb_data_test`
2. Setup an empty database:
   1. Stop your local server
   2. Rename your local `pb_data` to `pb_data_backup` (will be gitignored)
   3. Start without workers: Use `Backend (skip workers)` config
3. Create the data:
   1. **Outside the dev container**: Run `Tool: Test Seed` launch config.
   2. If it fails, repeat Step 2 to remove partially created data.
4. Use data for tests. Steps:
   1. Rename newly created `pb_data` to `pb_data_test`
5. Rename `pb_data_backup` back to `pb_data`
