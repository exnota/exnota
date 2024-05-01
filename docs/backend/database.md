# Database

## Migrations

### Key notes

- Schema migrations are automatically generated when modifying them in the Admin UI.
- Migrations appear to be run in transactions.
- App instance not available in migrations ([link](https://github.com/pocketbase/pocketbase/discussions/3234#discussioncomment-6874477)). It should be available after refactoring ([link](https://github.com/pocketbase/pocketbase/discussions/4355#discussion-6221763)).

### Create migration manually

1. `go run cmd/main.go migrate create "your_new_migration"`
2. It will generate a file with space for up and down migration. See examples below.
3. To test locally, add breakpoints and run the server as normal.
   - Or `go run cmd/main.go migrate up`
4. To test the down migration: `go run cmd/main.go migrate down 1`
   - This will run the last migration's down function.

### Examples of manual migrations

For reference, since it's hard to distinguish between manually and automatically created migrations, here are some created manually:

- migrations/1705477809_default_block_type.go
- migrations/1714182555_initialize_integration_status_connected.go

### Manual rollback

```bash
# Rollback the last migration ("1" means rollback the last one migration)
go run cmd/main.go migrate down 1
```

### Docs

<https://pocketbase.io/docs/go-migrations>
