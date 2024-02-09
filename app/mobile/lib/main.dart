import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/env/device_info.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/log/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

void main() async {
  print('Starting main');

  // Needed for the database, Firebase, and more. Don't know why :)
  WidgetsFlutterBinding.ensureInitialized();

  // Device info
  final deviceInfo = await initDeviceInfo();

  // Reporting
  await initCrashlytics();

  // Database
  final localFilePathGenerator = await initLocalFilePathGenerator();
  final db = initDatabase(files: localFilePathGenerator);

  // Overrides
  final overrides = getOverrides(
    db: db,
    deviceInfo: deviceInfo,
    localFilePathGenerator: localFilePathGenerator,
  );

  // Sync command runner
  // await initSyncCommands(overrides: overrides);

  // TODO: If I can load theme here rather than after calling runApp, I might
  // be able to avoid the flash of white when the user wants to be in dark
  // mode.

  runApp(ProviderScope(overrides: overrides, child: const MyApp()));
}

List<Override> getOverrides(
    {required LocalPathGenerator localFilePathGenerator,
    required AppDatabase db,
    required DeviceInfo deviceInfo}) {
  return [
    localFilePathServiceProvider.overrideWithValue(localFilePathGenerator),
    databaseProvider.overrideWithValue(db),
    deviceInfoProvider.overrideWithValue(deviceInfo)
  ];
}
