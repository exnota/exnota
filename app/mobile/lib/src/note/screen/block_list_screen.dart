import 'package:exnota/src/context/app/route.dart';
import 'package:exnota/src/context/os/connection.dart';
import 'package:exnota/src/context/user/refresh_queue.dart';
import 'package:exnota/src/lib/data/sync/service/block_importer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exnota/src/note/service/block_lister.dart';
import 'package:go_router/go_router.dart';

class BlockListScreen extends ConsumerStatefulWidget {
  const BlockListScreen({super.key});

  @override
  ConsumerState<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends ConsumerState<BlockListScreen> {
  BlockImporter? _blockImporter;

  // init
  @override
  void initState() {
    super.initState();

    // When implementing, I got an error reading from ref directly inside
    // initState. Doing it within Future.delayed is a workaround.
    //
    // A better solution may be to perform this in build().
    Future.delayed(Duration.zero, () async {
      final blockImporter = ref.read(blockImporterProvider);
      await blockImporter.subscribe();

      // Check if mounted to avoid a race condition when logging out that
      // results in this block being executed after the widget is disposed.
      if (mounted) {
        // Call setState because, even though we're inside initState, this is
        // being delayed. Assuming that's appropriate.
        setState(() {
          _blockImporter = blockImporter;
        });
      }
    });
  }

  @override
  void dispose() {
    _blockImporter?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.note_list_title),
        actions: [
          IconButton(
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              context.push(to(Screen.settings));
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      floatingActionButton: ButtonBar(
        children: [
          FloatingActionButton(
            onPressed: () {
              // Add test requests
              ref.read(refreshQueueProvider.notifier).addMultipleRequests([
                ListNotesRequestOne(),
                ListNotesRequestTwo(),
              ]);
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isOffline)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).secondaryHeaderColor,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined),
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    'Offline',
                  )
                ],
              ),
            ),
          const Expanded(child: BlockList()),
        ],
      ),
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
          onRefresh: () async => print('refresh'),
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final block = data[index].block;
              return ListTile(
                title: Text(block.title ?? ''),
              );
            },
          ),
        );
      },
    );
  }
}
