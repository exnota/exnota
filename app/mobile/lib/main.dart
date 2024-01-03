import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_initializer.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/log/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/account/settings/settings_controller.dart';
import 'src/account/settings/settings_service.dart';

void main() async {
  print('Starting main');

  // Needed for the database, Firebase, and more. Don't know why :)
  WidgetsFlutterBinding.ensureInitialized();

  // Reporting
  await initCrashlytics();

  // Database
  final localFilePathGenerator = await initLocalFilePathGenerator();
  final db = initDatabase(files: localFilePathGenerator);

  // Overrides
  final overrides = getOverrides(
    localFilePathGenerator: localFilePathGenerator,
    db: db,
  );

  // Sync command runner
  await initSyncCommands(overrides: overrides);

  // Settings
  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());
  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsScreen.
  runApp(ProviderScope(
      overrides: overrides,
      child: MyApp(settingsController: settingsController)));
}

List<Override> getOverrides(
    {required LocalPathGenerator localFilePathGenerator,
    required AppDatabase db}) {
  return [
    localFilePathServiceProvider.overrideWithValue(localFilePathGenerator),
    databaseProvider.overrideWithValue(db),
  ];
}
