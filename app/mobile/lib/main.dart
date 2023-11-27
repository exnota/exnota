import 'package:exnota/database.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/data/sync/sync_command_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/account/settings/settings_controller.dart';
import 'src/account/settings/settings_service.dart';

void main() async {
  final mainLogger = Logger();

  // Needed for the database. Don't know why :)
  WidgetsFlutterBinding.ensureInitialized();

  final db = initDatabase();
  final commandRepo = SyncCommandRepo(db);
  commandRepo
      .fetchAllStream(status: SyncCommandStatus.waiting)
      .listen((commands) async {
    mainLogger.debug("Found commands", commands);
    if (commands.isEmpty) {
      return;
    }
    final command = commands[0];
    final result = await command.request();
    mainLogger.debug("Command result", result);
    await commandRepo.setStatus(command.entityId, SyncCommandStatus.complete);
    mainLogger.debug("Command status updated");
  });

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsScreen.
  runApp(ProviderScope(overrides: [
    databaseProvider.overrideWithValue(db),
  ], child: MyApp(settingsController: settingsController)));
}
