import 'package:exnota/src/integration/service/notion_connected_service.dart';
import 'package:exnota/src/integration/view/notion_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:exnota/src/account/settings/settings_view.dart';

class NoteListView extends ConsumerWidget {
  const NoteListView({
    super.key,
  });

  static const routeName = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notionConnected = ref.watch(notionConnectedServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exnota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),

      // To work with lists that may contain a large number of items, it’s best
      // to use the ListView.builder constructor.
      //
      // In contrast to the default ListView constructor, which requires
      // building all Widgets up front, the ListView.builder constructor lazily
      // builds Widgets as they’re scrolled into view.
      body: switch (notionConnected) {
        true => const Text("COnnected"),
        false => Center(
            child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotionSettingsView()),
                  );
                },
                child:
                    Text(AppLocalizations.of(context)!.note_connectToNotion)),
          )
      },
      floatingActionButton: switch (notionConnected) {
        false => null,
        true => FloatingActionButton.extended(
            onPressed: () {},
            label: const Text('Record'),
            icon: const Icon(Icons.mic),
          )
      },
    );
  }
}
