import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/import_request_queue.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/audio/audio_block_recorder.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exnota/src/note/service/block_lister.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

class BlockListScreen extends ConsumerStatefulWidget {
  const BlockListScreen({super.key});

  @override
  ConsumerState<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends ConsumerState<BlockListScreen> {
  final Logger _log = Logger(context: 'BlockListScreen');
  AudioBlockRecorder? _recorder;

  // init
  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _log.debug('didChangeDependencies');
    // Can't call this in initState because context is not available yet.
    _recorder =
        AudioBlockRecorder(container: ProviderScope.containerOf(context));
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    // Don't stop the recorder here, to allow the user to navigate while a
    // recording is in progress.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connStatus = ref.watch(connectionStatusProvider);
    final hasUnexpectedError =
        ref.watch(importRequestQueueUnexpectedErrorProvider);

    return ListenableBuilder(
      listenable: _recorder!,
      builder: (context, widget) {
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
              // FloatingActionButton(
              //   onPressed: () {
              //     ref.read(connectionStatusProvider.notifier).setUserRetry();
              //   },
              //   child: const Icon(Icons.restart_alt),
              // ),
              // FloatingActionButton(
              //   onPressed: () {
              //     ref.read(connectionStatusProvider.notifier).setUnauthenticated();
              //   },
              //   child: const Icon(Icons.logout),
              // ),
              if (!_recorder!.recording)
                FloatingActionButton(
                  onPressed: () async {
                    await _recorder!.record();
                  },
                  child: const Icon(Icons.mic),
                ),
              if (_recorder!.recording)
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () async {
                    await _recorder!.stop();
                  },
                  child: const Icon(Icons.stop),
                ),
              // FloatingActionButton(
              //   onPressed: () {
              //     // ref.read(connectionStatusProvider.notifier).setOffline();
              //     // Add test requests
              //     // ref.read(pocketBaseProvider).authStore.clear();
              //     ref
              //         .read(importRequestQueueProvider.notifier)
              //         .addMultipleRequests([
              //       ListNotesRequestOne(),
              //       ListNotesRequestTwo(),
              //     ]);
              //   },
              //   child: const Icon(Icons.add),
              //   // child: const Icon(Icons.cloud_off),
              // ),
            ],
          ),
          body: Column(
            children: [
              if (connStatus == ConnStatus.unauthenticated)
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
                            ref
                                .read(userContextServiceSyncProvider.notifier)
                                .logout();
                          },
                          child: const Text('Sign in')),
                    ],
                  ),
                )
              else if (hasUnexpectedError)
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
                            ref
                                .read(importRequestQueueProvider.notifier)
                                .retry();
                          },
                          child: const Text('Retry')),
                    ],
                  ),
                )
              else if (connStatus == ConnStatus.offline)
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
                        'Offline',
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          ref
                              .read(connectionStatusProvider.notifier)
                              .setUserRetry();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (connStatus == ConnStatus.userRetry)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).secondaryHeaderColor,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Retrying',
                      )
                    ],
                  ),
                ),
              const Expanded(child: BlockList()),
            ],
          ),
        );
      },
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
                title: Text(block.title ??
                    'Syncing... (created ${DateFormat('yyyy-MM-dd H:m:s').format(block.userCreated)})'),
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
    await Future.delayed(const Duration(seconds: 5));

    final result = await pb
        .collection(collectionBlock)
        .getFullList(sort: '-created')
        .timeout(const Duration(seconds: 5));
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
    await Future.delayed(const Duration(seconds: 5));

    final result = await pb
        .collection(collectionBlock)
        .getFullList(sort: '-created')
        .timeout(const Duration(seconds: 5));
    _log.debug('Listed ${result.length} notes');

    _log.debug('Request complete');
  }
}
