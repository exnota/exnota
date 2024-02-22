# Sync

## Import

* **On logout, any in-progress requests will attempt to complete.**
  * So requests should be constructed so that if the user is logged out partway through, it will gracefully fail.
  * We could implement `CancelableOperation` but that would require putting `isCancelled` checks throughout each request implementation. [See example](https://github.com/dart-lang/sdk/issues/42855#issuecomment-664663574).
