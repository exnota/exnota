# Test

## Pocketbase integration

* The test directory won't be modified as it is [cloned by the test helper](https://github.com/pocketbase/pocketbase/blob/3f7db19fdd83774dabe83337523e863773e23689/tests/app.go#L473).

## Updating test seed data

1. Delete test data
   1. Delete `test_pb_data`
2. Start Pocketbase with an empty database
   1. Stop your local server
   2. Rename or delete your local `pb_data`
   3. Start the server
3. Create the data
   1. Run the `Tool: Test Seed` launch config (which executes `tool/test-seed/index.ts`)
4. Use data for tests
   1. Rename newly created `pb_data` to `test_pb_data`
   2. Collection IDs in Go tests may need to be updated.
5. Optional: Restore your local `pb_data` if you renamed it.