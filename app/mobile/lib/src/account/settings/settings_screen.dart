import 'package:drift_db_viewer/drift_db_viewer.dart';
import 'package:exnota/src/block/repo/drift/destination_importer.dart';
import 'package:exnota/src/block/repo/drift/workspace_importer.dart';
import 'package:exnota/src/block/service/destination_lister.dart';
import 'package:exnota/src/context/app/local_settings.dart';
import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/environment/environment.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Need to wrap in Future to avoid provider throwing an error that its
    // state was modified during the widget's lifecycle.
    Future.wait([
      ref.read(workspaceImporterProvider.notifier).import(),
      ref.read(destinationImporterProvider.notifier).importAll(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeSettingProvider);
    final environment = ref.watch(environmentServiceSyncProvider);
    final destination = ref.watch(activeDestinationLazyProvider);

    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(title: const Text('Account'), tiles: [
              if (destination == null)
                SettingsTile(
                  title: const Text('Connect to Notion'),
                  description: const Text('Choose where notes are saved'),
                  descriptionInlineIos: true,
                  leading: const Icon(Icons.source),
                  onPressed: (BuildContext context) {
                    ref
                        .read(routerProvider.notifier)
                        .go(Screen.settingsSetupIntegration);
                  },
                )
              else
                SettingsTile(
                  title: const Text('Change notes destination'),
                  description:
                      Text('Saving to \'${destination.name}\' in Notion'),
                  descriptionInlineIos: true,
                  leading: const Icon(Icons.source),
                  onPressed: (BuildContext context) {
                    ref
                        .read(routerProvider.notifier)
                        .go(Screen.settingsSetupIntegrationForceReauth);
                  },
                ),
              SettingsTile(
                title: const Text('Sign out'),
                leading: const Icon(Icons.exit_to_app),
                onPressed: (BuildContext context) async {
                  await ref
                      .read(userContextServiceSyncProvider.notifier)
                      .logout();
                },
              ),
            ]),
            // This section has less bottom margin due to descriptionInlineIos=true
            SettingsSection(
              title: const Text('Appearance'),
              tiles: [
                SettingsTile(
                  title: const Text('Theme'),
                  description: switch (themeMode) {
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
                        return const ThemeModeBottomSheet();
                      },
                    );
                  },
                ),
              ],
            ),

            if (kDebugMode)
              SettingsSection(title: const Text('Developer'), tiles: [
                SettingsTile(
                  title:
                      const Text('Environment (changing here might be buggy)'),
                  description: Text(environment.toString()),
                  leading: const Icon(Icons.cloud_outlined),
                  descriptionInlineIos: true,
                  onPressed: (BuildContext context) {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return const EnvironmentBottomSheet();
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

class ThemeModeBottomSheet extends ConsumerWidget {
  const ThemeModeBottomSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeSettingProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RadioListTile(
          // TODO: Translation (and above/below)
          title: const Text('Light mode'),
          value: ThemeMode.light,
          groupValue: themeMode,
          onChanged: (newThemeMode) async {
            // Navigator.pop(context);
            await ref
                .read(themeModeSettingProvider.notifier)
                .setThemeMode(newThemeMode);
          },
        ),
        RadioListTile(
          title: const Text('Dark mode'),
          value: ThemeMode.dark,
          groupValue: themeMode,
          onChanged: (newThemeMode) async {
            // Navigator.pop(context);
            await ref
                .read(themeModeSettingProvider.notifier)
                .setThemeMode(newThemeMode);
          },
        ),
        RadioListTile(
          title: const Text('Use device settings'),
          subtitle: const Text('We\'ll use your device display theme'),
          value: ThemeMode.system,
          groupValue: themeMode,
          onChanged: (newThemeMode) async {
            // Navigator.pop(context);
            await ref
                .read(themeModeSettingProvider.notifier)
                .setThemeMode(newThemeMode);
          },
        ),
      ],
    );
  }
}

class EnvironmentBottomSheet extends ConsumerWidget {
  const EnvironmentBottomSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(environmentServiceSyncProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RadioListTile(
          title: const Text('Production'),
          value: Environment.prod,
          groupValue: environment,
          onChanged: (newEnvironment) async {
            // Note: There might be some race conditions here
            // due to the setting of the environment and
            // logging out being non-transactional. A
            // re-render might happen between both and result
            // in an invalid/buggy state.
            //
            // TODO: Changing the environment context should
            // cause a re-render of the entire app. Maybe
            // something can be changed in that context layer
            // so that user auth is essentially reset when
            // the environment changes.

            final userContextNotifier =
                ref.read(userContextServiceSyncProvider.notifier);

            await ref
                .read(environmentServiceSyncProvider.notifier)
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
          groupValue: environment,
          onChanged: (newEnvironment) async {
            // Note: See above (in the production case)

            final userContextNotifier =
                ref.read(userContextServiceSyncProvider.notifier);

            await ref
                .read(environmentServiceSyncProvider.notifier)
                .setEnvironment(newEnvironment);
            // ref is no longer accessible here because
            // the entire app tree starts rebuilding when
            // the environment is changed.
            await userContextNotifier.logout();
          },
        ),
      ],
    );
  }
}
