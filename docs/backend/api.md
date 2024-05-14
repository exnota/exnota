# API

* Pocketbase accepts requests as JSON or multipart form
  * File uploads likely require multipart.
  * Admin interface uses multipart for all requests.

* Calling `context.String()` sets the requeset response, it doesn't return it.
  * So when outside of `e.Router.[METHOD]` you can't return that call.
