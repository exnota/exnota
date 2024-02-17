# Patterns

## Providers

### Create `refresh` methods

This makes it more explicit where consumers may be refreshing a providers state.

E.g.

```dart
// ✅
// In consumer:
ref.read(someProvider.notifier).refresh();

// In provider
void refresh() {
  ref.invalidateSelf();
}


// ❌
// In consumer
ref.refresh(someProvider);

```
