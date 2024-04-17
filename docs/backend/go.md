# Go

## Upgrading version

1. Skim release notes.
2. Update version number in `go.mod`
3. Update version number in `Dockerfile` in `FROM`
4. Rebuild local Dev Container

## Patterns

### Enum for types

Have been using the following pattern:

```go
type Status string

const (
	StatusWaiting  Status = "waiting"
	StatusRunning  Status = "running"
	StatusComplete Status = "complete"
	StatusError    Status = "error"
)
```

These are not strongly typed! Passing any string is valid.

To validate at runtime, you can use the [validator](https://github.com/go-playground/validator) package's [`oneof`](https://pkg.go.dev/github.com/go-playground/validator/v10#hdr-One_Of):

```go
type Json struct {
	Status Status `validate:"oneof=waiting running complete error"`
}
```

Or possibly a custom validator: https://github.com/go-playground/validator/blob/master/_examples/custom-validation/main.go

## Other

- Formatting: See [local](local.md#vs-code-workspace)
