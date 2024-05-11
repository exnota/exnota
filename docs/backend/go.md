# Go

- [Upgrading version](#upgrading-version)
- [Patterns](#patterns)
	- [Error handling](#error-handling)
	- [Validation](#validation)
	- [Enum for types](#enum-for-types)
- [Other](#other)


## Upgrading version

1. Skim release notes.
2. Update version number in `go.mod`
3. Update version number in `Dockerfile` in `FROM`
4. Rebuild local Dev Container

## Patterns

### Error handling

- Wrap errors when more context may be helpful for debugging.
- Check for wrapped sentinal errors with `errors.Is`
- Avoid swallowing errors. Better to make issues more obvious so they can be resolved, even if it results in a temporarily (perceived) worse user experience.
- Use panics when continuing is unsafe or there are serious programming errors like incorrect parameters.

Article: https://medium.com/@nouhoum/mastering-error-handling-in-go-0239f229c6c8

### Validation

- Select field values are validated by `form.Submit()`
  - So enums to be persisted don't need to have their values validated if this will be called.
  - This is important since Go enums aren't strongly typed (see [Enum for types](#enum-for-types)).

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
