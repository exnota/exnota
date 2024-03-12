// const _countKey = 'counter';
import 'package:home_widget/home_widget.dart';

const _statusKey = 'status';

/// Gets the currently stored Value
Future<bool> get _value async {
  final value =
      await HomeWidget.getWidgetData<bool>(_statusKey, defaultValue: false);
  return value!;
}

/// Retrieves the current stored value
/// Increments it by one
/// Saves that new value
/// @returns the new saved value
Future<bool> widgetToggle() async {
  final oldValue = await _value;
  final newValue = !oldValue;
  await widgetSendAndUpdate(newValue);
  return newValue;
}

/// Clears the saved Counter Value
// Future<void> _clear() async {
//   await _sendAndUpdate(null);
// }

/// Stores [value] in the Widget Configuration
Future<void> widgetSendAndUpdate([bool? value]) async {
  await HomeWidget.saveWidgetData(_statusKey, value);
  await HomeWidget.updateWidget(
    iOSName: 'RecordWidget',
    // androidName: 'CounterWidgetProvider',
  );
}
