import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Initiates Notion auth process.
class ConnectToNotionView extends StatelessWidget {
  const ConnectToNotionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.integration_connectToNotion),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: null,
      ),
    );
  }
}
