import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/user/import_queue.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exnota/src/note/service/block_lister.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

class BlockListScreen extends ConsumerStatefulWidget {
  const BlockListScreen({super.key});

  @override
  ConsumerState<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends ConsumerState<BlockListScreen> {
  final Logger _log = Logger(context: 'BlockListScreen');

  // init
  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isImportQueueErrored = ref.watch(importQueueErroredProvider);
    final isImportQeueAuthErrored = ref.watch(importQueueAuthErroredProvider);

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
              ref.read(importQueueProvider.notifier).addMultipleRequests([
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
          // TODO: #37 Consolidate this offline notice with the refresh queue errors
          // if (isOffline)
          //   Container(
          //     decoration: BoxDecoration(
          //       color: Theme.of(context).secondaryHeaderColor,
          //     ),
          //     child: const Row(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         Icon(Icons.cloud_off_outlined),
          //         SizedBox(
          //           width: 10,
          //         ),
          //         Text(
          //           'Offline',
          //         )
          //       ],
          //     ),
          //   ),
          if (isImportQeueAuthErrored)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).secondaryHeaderColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(
                    width: 10,
                  ),
                  const Text(
                    'You need to sign in again.',
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  FilledButton.tonal(
                      onPressed: () {
                        ref.read(userContextServiceProvider.notifier).logout();
                      },
                      child: const Text('Sign in')),
                ],
              ),
            )
          else if (isImportQueueErrored)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).secondaryHeaderColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(
                    width: 10,
                  ),
                  const Text(
                    'Unable to sync.',
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  FilledButton.tonal(
                      onPressed: () {
                        ref.read(importQueueProvider.notifier).retry();
                      },
                      child: const Text('Retry')),
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

class ListNotesRequestOne extends ImportRequest<List<RecordModel>> {
  final _log = Logger(context: 'ListNotesRequestOne');

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Requesting list of notes');

    // wait 5 seconds
    await Future.delayed(const Duration(seconds: 10));

    final result =
        await pb.collection(collectionBlock).getFullList(sort: '-created');
    _log.debug('Listed ${result.length} notes');

    _log.debug('Request complete');
  }
}

class ListNotesRequestTwo extends ImportRequest<List<RecordModel>> {
  final _log = Logger(context: 'ListNotesRequestTwo');

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Requesting list of notes');

    // wait 5 seconds
    await Future.delayed(const Duration(seconds: 10));

    final result =
        await pb.collection(collectionBlock).getFullList(sort: '-created');
    _log.debug('Listed ${result.length} notes');

    _log.debug('Request complete');
  }
}
