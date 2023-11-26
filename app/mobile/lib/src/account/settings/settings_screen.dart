import 'package:exnota/src/account/settings/environment_service.dart';
import 'package:exnota/src/integration/screen/notion_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(environmentServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          // Glue the SettingsController to the theme selection DropdownButton.
          //
          // When a user selects a theme from the dropdown list, the
          // SettingsController is updated, which rebuilds the MaterialApp.
          child: Column(
            children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotionSettingsScreen()),
                    );
                  },
                  child: const Text("Configure Notion")),
              DropdownButton<ThemeMode>(
                // Read the selected themeMode from the controller
                value: controller.themeMode,
                // Call the updateThemeMode method any time the user selects a theme.
                onChanged: controller.updateThemeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System Theme'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light Theme'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark Theme'),
                  )
                ],
              ),
              if (kDebugMode)
                DropdownButton<Environment>(
                  // Read the selected themeMode from the controller
                  value: environment,
                  // Call the updateThemeMode method any time the user selects a theme.
                  onChanged: (Environment? environment) {
                    if (environment != null) {
                      ref
                          .read(environmentServiceProvider.notifier)
                          .setEnvironment(environment);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: Environment.prod,
                      child: Text('Prod'),
                    ),
                    DropdownMenuItem(
                      value: Environment.local,
                      child: Text('Local'),
                    ),
                  ],
                ),
            ],
          )),
    );
  }
}
