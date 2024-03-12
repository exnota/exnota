# Sync

## Requests

Each request to the backend should update the connection status if it could not be reached or if the user is no longer authenticated.

There are two services for this:

- `importRequestQueueProvider`: For requests that import data based on state changes, can be paused when others are blocked, and should be de-duplicated.
- pocketBaseRequestProvider: For other requests.

## Import

- **On logout, any in-progress requests will attempt to complete.**
  - So requests should be constructed so that if the user is logged out partway through, it will gracefully fail.
  - We could implement `CancelableOperation` but that would require putting `isCancelled` checks throughout each request implementation. [See example](https://github.com/dart-lang/sdk/issues/42855#issuecomment-664663574).
