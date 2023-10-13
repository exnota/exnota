import 'package:Exnota/src/integration/notion_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Initiates Notion auth process.
class ConnectToNotionView extends StatelessWidget {
  const ConnectToNotionView({super.key});

  @override
  Widget build(BuildContext context) {
    const settings = NotionSettings(code: 'test code');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.integration_connectToNotion),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Code: ${settings.code}'),
      ),
    );
  }
}
