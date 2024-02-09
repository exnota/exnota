# Provider

## Eager initialization of async providers

There are two approaches. Both work for async providers. [Official docs](https://riverpod.dev/docs/essentials/eager_initialization).

### 1. Before runApp() is called

Best for: Providers returning a simple object with no side-effects.

- Create an unimplemented provider.
- Create an init method that creates the object.
- In `main.go`, call init method and use the value to override the unimplemented provider.

Example: See the database provider in `lib/src/lib/data/drift/database.dart`.

### 2. Use a wrapper component

Best for: Providers that have side effects.

Caveat: Must still use a `Future` return type on the provider, which returns an `AsyncValue` type that needs loading/error states handled.

Caveat workaround: Use `.requireValue` on the returned `AsyncValue` skip the loading/error states and get the value. This will throw if the data isn't correctly eagerly initialized.
