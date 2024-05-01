# Hooks

- Model hooks like OnModelBeforeCreate are fired on
  - Standard CRUD API requests
  - Using a form to update a record:

    ```go
    form := forms.NewRecordUpsert(b.app, record)
    err := form.Submit()
    ```

  - Saving a record directly: `app.Dao().SaveRecord`
    - This skips PocketBase validation so don't use without very good reason.
- Hooks don't share a transaction with their trigger
  - If **before** hooks return an error, the triggering CRUD operation won't happen.
  - When **after** hooks fire, the triggering CRUD operation has already completed.
- Returning an error or `hook.StopPropagation` prevents further hooks from firing.
  - This may not be desirable in some cases.
  - This means the order of hooks matters. Invariants before side effects.
