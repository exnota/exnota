import 'package:exnota/src/integration/service/notion_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This is for app store reviewers to be able to test the app. They provide a
// secret in place of a Notion access token, and if it matches what the backend
// expects, it will use an internal integration secret for a test account to
// auth with Notion.
class AlternateNotionSettingsView extends ConsumerStatefulWidget {
  const AlternateNotionSettingsView({super.key});

  @override
  ConsumerState<AlternateNotionSettingsView> createState() =>
      _AlternateNotionSettingsViewState();
}

enum LaunchingBrowserStatus { notLaunched, launched, returned }

class _AlternateNotionSettingsViewState
    extends ConsumerState<AlternateNotionSettingsView> {
  final controller = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alternate Notion Settings'),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  TextField(
                    onSubmitted: (value) {
                      _saveSecret(value);
                    },
                    controller: controller,
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () {
                      _saveSecret(controller.text);
                    },
                    child: const Text('Save'),
                  )
                ],
              ),
            ],
          )),
    );
  }

  void _saveSecret(String secret) async {
    await ref
        .read(notionSettingsServiceProvider.notifier)
        .setTokenForPlayConsoleTesting(secret);
    _navigateBack();
  }

  void _navigateBack() {
    Navigator.pop(context);
  }
}
