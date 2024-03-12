import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/import_request_queue.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exnota/src/note/service/block_lister.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:permission_handler/permission_handler.dart';

class BlockListScreen extends ConsumerStatefulWidget {
  const BlockListScreen({super.key});

  @override
  ConsumerState<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends ConsumerState<BlockListScreen> {
  final Logger _log = Logger(context: 'BlockListScreen');
  FlutterSoundRecorder? recorder;
  bool recording = false;

  // init
  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    recorder?.stopRecorder();
    recorder?.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connStatus = ref.watch(connectionStatusProvider);
    final hasUnexpectedError =
        ref.watch(importRequestQueueUnexpectedErrorProvider);

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
          FloatingActionButton(
            onPressed: () async {
              final micPermission = await Permission.microphone.request();
              if (micPermission.isGranted) {
                _log.debug('Mic permission granted');
              } else {
                _log.error('Mic permission denied');
                return;
              }
              setState(() {
                recorder = FlutterSoundRecorder();
              });
              if (recorder == null) {
                // TODO: Show some error?
                return;
              }

              // I assume this is opening a session, which is hopefully what
              // audio_session is properly configuring in main.dart.
              _log.debug('Opening recorder');
              await recorder?.openRecorder();
              setState(() {
                recording = true;
              });

              _log.debug('Getting file path');
              // generate random id for file
              final random = DateTime.now().millisecondsSinceEpoch.toString();
              final path = await ref
                  .read(localFilePathServiceProvider)
                  .generateAudioBlockFilePath(
                      blockId: 'test-$random', extension: 'wav');

              _log.debug('Starting recorder');
              await recorder?.startRecorder(
                  toFile: path, codec: Codec.pcm16WAV);
              // setState(() {
              //   recording = false;
              // });
            },
            child: const Icon(Icons.mic_outlined),
          ),
          FloatingActionButton(
            onPressed: () async {
              _log.debug('Stopping recorder');
              // setState(() {
              //   recording = false;
              // });
              final result = await recorder?.stopRecorder();
              _log.debug('Recorder stopped, recording at: $result');
              setState(() {
                recording = false;
              });

              // I assume this is closing a session, which is hopefully what
              // audio_session is properly configuring in main.dart.
              _log.debug('Closing recorder');
              await recorder?.closeRecorder();
            },
            child: const Icon(Icons.mic_external_off),
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
                        ref.read(userContextServiceProvider.notifier).logout();
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
                        ref.read(importRequestQueueProvider.notifier).retry();
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
