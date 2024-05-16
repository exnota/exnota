# API

## Pattern decisions

* Archived entities
  * ✅ Can be directly viewed/listed
    * Ensures apps know when they have been archived.
  * ❌ Cannot be viewed/listed as a relation
    * E.g. listing an integration's workspaces should omit those archived.
    * Not sure how PocketBase handles this. If it's default behaviour, don't fight it.
  * ❌ Cannot be modified or used for other operations
    * E.g. getting suggested destinations for an archived workspace should return an error.

## Pocketbase notes

* Pocketbase accepts requests as JSON or multipart form
  * File uploads likely require multipart.
  * Admin interface uses multipart for all requests.

* Calling `context.String()` sets the requeset response, it doesn't return it.
  * So when outside of `e.Router.[METHOD]` you can't return that call.
