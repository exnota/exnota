import 'package:Exnota/src/integration/notion_settings.dart';
import 'package:Exnota/src/integration/service/notion_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Initiates Notion auth process.
class ConnectToNotionView extends ConsumerStatefulWidget {
  const ConnectToNotionView({super.key});

  @override
  ConsumerState<ConnectToNotionView> createState() => _ConnectToNotionView();
}

class _ConnectToNotionView extends ConsumerState<ConnectToNotionView> {
  @override
  Widget build(BuildContext context) {
    final notionSettings = ref.watch(notionSettingsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.integration_connectToNotion),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (notionSettings) {
            AsyncError() => const Text('error'),
            AsyncLoading() => const CircularProgressIndicator(),
            AsyncData(:final value) => switch (value) {
                NotionSettingsEmpty() => OutlinedButton(
                    onPressed: () {
                      // TODO: Start process
                    },
                    child: const Text('Start')),
                NotionSettingsCode() => Text('Code: ${value.code}'),
                NotionSettingsAccessToken() =>
                  Text('Access token: ${value.accessToken}')
              },
            AsyncValue() => throw Exception('Unhandled value')
          }),
    );
  }
}
