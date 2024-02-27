# Test

## Mocking

### Mocking a callback

Example: `test/context/sync/connection_listener_test.dart`

```dart
abstract class MyFunction {
  void call();
}
class MyFunctionMock extends Mock implements MyFunction {}

void main() {
  final mock = MyFunctionMock();

  // in test():
  someClass.passCallback(mock);
  verify(mock()).called(1);
}
```

Source: <https://github.com/dart-lang/mockito/issues/62#issuecomment-817896673>

### Testing async non-widget code

Use [fake_async](https://pub.dev/packages/fake_async), and [clock.now()](https://pub.dev/packages/fake_async#integration-with-clock) instead of DateTime.now().

### Testing async widget code

Use [testWidgets](https://api.flutter.dev/flutter/flutter_test/testWidgets.html).
