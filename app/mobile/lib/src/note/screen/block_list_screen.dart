import 'package:drift_db_viewer/drift_db_viewer.dart';
import 'package:exnota/src/account/user/service/user_context_service.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exnota/src/note/service/block_lister.dart';

class BlockListScreen extends ConsumerStatefulWidget {
  static const routeName = '/';

  const BlockListScreen({super.key});

  @override
  ConsumerState<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends ConsumerState<BlockListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.note_list_title),
        actions: [
          if (kDebugMode)
            IconButton(
                icon: const Icon(Icons.storage),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          DriftDbViewer(ref.read(databaseProvider))));
                }),
          IconButton(
              onPressed: () async {
                await ref.read(userContextServiceProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: const BlockList(),
    );
  }
}

class BlockList extends ConsumerWidget {
  const BlockList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(blockListerProvider);

    return blocks.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) {
        return Text('Error: $error');
      },
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(blockListerProvider.notifier).refresh(),
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(data[index].title),
              );
            },
          ),
        );
      },
    );
  }
}
