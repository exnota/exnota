# Scenarios

A list of paths and edge cases to test in the future.

## Fetching data

### Network error

- On temporary (~10 sec) network error, recovers without notifying user.
- On longer (10+ sec) network error, provides a way for user to try again.
  - On success, continues with all expected data updated.
  - On failure, provides the retry method again.

## Auth error

- On auth error, provides a way for user to log out and log back in.
  - On success, continues with all expected data updated.
-
