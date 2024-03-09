import 'package:exnota/src/context/device/device_info.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/lib/log/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'src/app.dart';

const _countKey = 'counter';

/// Gets the currently stored Value
Future<int> get _value async {
  final value = await HomeWidget.getWidgetData<int>(_countKey, defaultValue: 0);
  return value!;
}

/// Retrieves the current stored value
/// Increments it by one
/// Saves that new value
/// @returns the new saved value
Future<int> _increment() async {
  final oldValue = await _value;
  final newValue = oldValue + 1;
  await _sendAndUpdate(newValue);
  return newValue;
}

/// Clears the saved Counter Value
Future<void> _clear() async {
  await _sendAndUpdate(null);
}

/// Stores [value] in the Widget Configuration
Future<void> _sendAndUpdate([int? value]) async {
  await HomeWidget.saveWidgetData(_countKey, value);
  await HomeWidget.updateWidget(
    iOSName: 'CounterWidget',
    androidName: 'CounterWidgetProvider',
  );
}

@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  // We check the host of the uri to determine which action should be triggered.
  if (uri?.host == 'increment') {
    await _increment();
  } else if (uri?.host == 'clear') {
    await _clear();
  }
}

void main() async {
  final log = Logger(context: 'main');
  log.debug('Starting main');

  // Needed for the database, Firebase, and more. Don't know why :)
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize device-context services
  final deviceInfo = await initDeviceInfoService();
  await initCrashlytics();
  final localFilePathGenerator = await initLocalFilePathGenerator();
  final db = initDatabase(files: localFilePathGenerator);

  // Overrides
  final overrides = getOverrides(
    db: db,
    deviceInfo: deviceInfo,
    localFilePathGenerator: localFilePathGenerator,
  );

  // TODO: Move sync command runner init to inside the user context
  // (possibly inside a workspace context)
  //
  // Sync command runner
  // await initSyncCommands(overrides: overrides);

  // Set AppGroup Id. This is needed for iOS Apps to talk to their WidgetExtensions
  await HomeWidget.setAppGroupId('group.exnotarecord');
  // Register an Interactivity Callback. It is necessary that this method is static and public
  await HomeWidget.registerInteractivityCallback(interactiveCallback);

  runApp(ProviderScope(overrides: overrides, child: const MyApp()));
}

List<Override> getOverrides(
    {required LocalPathGenerator localFilePathGenerator,
    required AppDatabase db,
    required DeviceInfo deviceInfo}) {
  return [
    localFilePathServiceProvider.overrideWithValue(localFilePathGenerator),
    databaseProvider.overrideWithValue(db),
    deviceInfoServiceProvider.overrideWithValue(deviceInfo)
  ];
}
