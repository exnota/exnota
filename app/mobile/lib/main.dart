import 'package:exnota/src/context/device/device_info.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/lib/log/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

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
