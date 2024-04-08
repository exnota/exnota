# Database

## Migrations

Automatically generated when modifying schema using UI.

### Docs

<https://pocketbase.io/docs/go-migrations>

### Manually rollback

```bash
# Rollback the last migration
go run cmd/main.go migrate down 1
```
