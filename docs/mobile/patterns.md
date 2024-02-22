# Patterns

## Providers

### Perform actions on state change

Use ref.listen in a wrapper widget:

* [Provider example, pre-Riverpod](https://github.com/rrousselGit/riverpod/issues/238#issuecomment-743776522).
* [Riverpod example with ref.listen](https://github.com/rrousselGit/riverpod/discussions/562#discussion-3442349)

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
