import 'package:drift_db_viewer/drift_db_viewer.dart';
import 'package:exnota/src/account/settings/settings_service.dart';
import 'package:exnota/src/account/user/service/user_context_service.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Already loaded with _EagerProviderLoader, so safe to use requireValue.
    final settings = ref.watch(settingsServiceProvider).requireValue;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: SettingsList(
          sections: [
            // This section has less bottom margin due to descriptionInlineIos=true
            SettingsSection(
              title: const Text('Appearance'),
              tiles: [
                SettingsTile(
                  title: const Text('Theme'),
                  description: switch (settings.themeMode) {
                    ThemeMode.dark => const Text('Dark mode'),
                    ThemeMode.light => const Text('Light mode'),
                    ThemeMode.system => const Text('Use system settings'),
                  },
                  leading: const Icon(Icons.sunny),
                  descriptionInlineIos: true,
                  onPressed: (BuildContext context) {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile(
                              // TODO: Translation (and above/below)
                              title: const Text('Light mode'),
                              value: ThemeMode.light,
                              groupValue: settings.themeMode,
                              onChanged: (newThemeMode) async {
                                Navigator.pop(context);
                                await ref
                                    .read(settingsServiceProvider.notifier)
                                    .setThemeMode(newThemeMode);
                              },
                            ),
                            RadioListTile(
                              title: const Text('Dark mode'),
                              value: ThemeMode.dark,
                              groupValue: settings.themeMode,
                              onChanged: (newThemeMode) async {
                                Navigator.pop(context);
                                await ref
                                    .read(settingsServiceProvider.notifier)
                                    .setThemeMode(newThemeMode);
                              },
                            ),
                            RadioListTile(
                              title: const Text('Use device settings'),
                              subtitle: const Text(
                                  'We\'ll use your device display theme'),
                              value: ThemeMode.system,
                              groupValue: settings.themeMode,
                              onChanged: (newThemeMode) async {
                                Navigator.pop(context);
                                await ref
                                    .read(settingsServiceProvider.notifier)
                                    .setThemeMode(newThemeMode);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            SettingsSection(title: const Text('Account'), tiles: [
              SettingsTile(
                  title: const Text('Sign out'),
                  leading: const Icon(Icons.exit_to_app),
                  onPressed: (BuildContext context) async {
                    await ref
                        .read(userContextServiceProvider.notifier)
                        .logout();
                  })
            ]),
            SettingsSection(title: const Text('Developer'), tiles: [
              SettingsTile(
                title: const Text('Environment'),
                description: Text(settings.environment.toString()),
                leading: const Icon(Icons.cloud_outlined),
                descriptionInlineIos: true,
                onPressed: (BuildContext context) {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile(
                            title: const Text('Production'),
                            value: Environment.prod,
                            groupValue: settings.environment,
                            onChanged: (newEnvironment) async {
                              Navigator.pop(context); // Close the bottom sheet
                              Navigator.pop(
                                  context); // Close the settings screen
                              final userContextNotifier =
                                  ref.read(userContextServiceProvider.notifier);

                              await ref
                                  .read(settingsServiceProvider.notifier)
                                  .setEnvironment(newEnvironment);
                              // ref is no longer accessible here because
                              // the entire app tree starts rebuilding when
                              // the environment is changed.
                              await userContextNotifier.logout();
                            },
                          ),
                          RadioListTile(
                            title: const Text('Local'),
                            value: Environment.local,
                            groupValue: settings.environment,
                            onChanged: (newEnvironment) async {
                              Navigator.pop(context); // Close the bottom sheet
                              Navigator.pop(
                                  context); // Close the settings screen
                              final userContextNotifier =
                                  ref.read(userContextServiceProvider.notifier);

                              await ref
                                  .read(settingsServiceProvider.notifier)
                                  .setEnvironment(newEnvironment);
                              // ref is no longer accessible here because
                              // the entire app tree starts rebuilding when
                              // the environment is changed.
                              await userContextNotifier.logout();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              SettingsTile(
                title: const Text('View database'),
                leading: const Icon(Icons.storage),
                onPressed: (BuildContext context) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          DriftDbViewer(ref.read(databaseProvider))));
                },
              ),
            ]),
          ],
        ));
  }
}
