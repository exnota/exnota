# Scenarios

A list of paths and edge cases to test in the future.

## Recording

- Widget and in-app recording are in sync.
  - You can't start a new recording from one if the other is in progress.
  - You can see that one is in progress from the other.
- Can recover if accidentally denied
  - iOS and Android

## Fetching data

### Network error

- On temporary (~10 sec) network error, recovers without notifying user.
- On longer (10+ sec) network error, provides a way for user to try again.
  - On success, continues with all expected data updated.
  - On failure, provides the retry method again.

## Auth error

- On auth error, provides a way for user to log out and log back in.
  - On success, continues with all expected data updated.

## Import

- On login, fetches the latest notes
- On app fresh start, fetches the latest notes
- Automatically receives note updates and new notes
  - When note list screen is open
  - When any other screen is open
  - When app is 'paused' briefly, then 'resumed'
    - Change app or press home button, then go back to Exnota.
  - When app is 'paused' for > 1 minute, then 'resumed'
    - As above, but wait 1 minute or longer before going to Exnota.
    - Why: Testing in the iOS simulator (for iPhone 7/iOS 15.5), a pause for less than ~1 min doesn't actually interfere with the normal automatic note updates. However, more than that does seem to pause them, so when the app is resumed we have code that does a full fetch of the latest notes.
