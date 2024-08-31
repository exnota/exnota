import 'package:exnota/src/block/repo/drift/destination_importer.dart';
import 'package:exnota/src/block/repo/drift/workspace_importer.dart';
import 'package:exnota/src/block/service/destination_lister.dart';
import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/import_request_queue.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/audio/audio_block_recorder.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exnota/src/block/service/block_lister.dart';
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
  bool showNotionCard = false; // Declare and initialize the variable

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
    final blocks = ref.watch(blocksLazyProvider);
    final destination = ref.watch(activeDestinationLazyProvider);
    final empty = blocks.isEmpty;
    ref.listen(blocksLazyProvider, (previous, next) {
      // Show Notion card after the user has done their first recording and it has
      // received a title. We want their eye drawn to the block card first, and
      // later to the Notion card.
      if (destination == null &&
          (previous == null ||
              previous.isEmpty ||
              previous.first.title == null ||
              previous.first.title!.isEmpty) &&
          next.isNotEmpty &&
          next.first.title != null &&
          next.first.title!.isNotEmpty) {
        // Set 2 second timer, then set state value: showNotionCard = true
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            showNotionCard = true;
          });
        });
      } else if (destination != null) {
        setState(() {
          showNotionCard = false;
        });
      }
    });

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
          bottomNavigationBar:
              showNotionCard ? const NotionConnectCard() : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton:
              empty ? null : RecordingButton(recorder: _recorder),
          body: Column(
            children: [
              Notice(
                  connStatus: connStatus,
                  ref: ref,
                  hasUnexpectedError: hasUnexpectedError),
              Expanded(
                  child: empty
                      ? FirstRecording(
                          recorder: _recorder,
                        )
                      : const BlockList()),
            ],
          ),
        );
      },
    );
  }
}

class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.connStatus,
    required this.ref,
    required this.hasUnexpectedError,
  });

  final ConnStatus connStatus;
  final WidgetRef ref;
  final bool hasUnexpectedError;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    ref.read(connectionStatusProvider.notifier).setUserRetry();
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
      ],
    );
  }
}

class RecordingButton extends StatelessWidget {
  const RecordingButton({
    super.key,
    required AudioBlockRecorder? recorder,
  }) : _recorder = recorder;

  final AudioBlockRecorder? _recorder;

  @override
  Widget build(BuildContext context) {
    return !_recorder!.recording
        ? FloatingActionButton(
            shape: const CircleBorder(),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            child: const Icon(Icons.mic),
            onPressed: () async {
              await _recorder!.record();
            },
          )
        : FloatingActionButton(
            shape: const CircleBorder(),
            backgroundColor: Colors.red,
            foregroundColor: const Color(0xFF1A0000).withOpacity(0.8),
            child: const Icon(Icons.stop),
            onPressed: () async {
              await _recorder!.stop();
            },
          );
  }
}

class FirstRecording extends ConsumerWidget {
  final AudioBlockRecorder? _recorder;

  const FirstRecording({
    super.key,
    required AudioBlockRecorder? recorder,
  }) : _recorder = recorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(workspaceImporterProvider.notifier).import(),
          ref.read(destinationImporterProvider.notifier).importAll(),
        ]);
      },
      child: Center(
        child: SingleChildScrollView(
          // This is needed to allow pulling to refresh
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Record your first \nvoice note!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),
                RecordingButton(recorder: _recorder),
              ],
            ),
          ),
        ),
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
          onRefresh: () async {
            await Future.wait([
              ref.read(workspaceImporterProvider.notifier).import(),
              ref.read(destinationImporterProvider.notifier).importAll(),
            ]);
          },
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final block = data[index].block;
              return ListTile(
                key: ValueKey(block.id),
                leading: switch (data[index].status) {
                  BlockStatus.waiting => const Icon(Icons.hourglass_empty),
                  BlockStatus.syncing || BlockStatus.transcribing => SizedBox(
                      height: 20.0, // This is the default size of an Icon
                      width: 20.0, // This is the default size of an Icon
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: IconTheme.of(context).color,
                      ),
                    ),
                  // TODO: This should also be a progress indicator once export
                  // to notion is implemented.
                  BlockStatus.synced ||
                  BlockStatus.exported =>
                    const Icon(Icons.check),
                  BlockStatus.error => const Icon(Icons.error),
                  BlockStatus.unknown => const Icon(Icons.question_mark),
                },
                title: Text(_title(block)),
              );
            },
          ),
        );
      },
    );
  }

  String _title(Block block) {
    if (block.title?.isNotEmpty ?? false) {
      return block.title!;
    }

    if (block.audio?.transcription?.isNotEmpty ?? false) {
      return block.audio!.transcription!.join(' ');
    }

    return 'Syncing... (created ${DateFormat('yyyy-MM-dd H:m:s').format(block.userCreated)})';
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

class NotionConnectCard extends ConsumerWidget {
  const NotionConnectCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 32.0,
              ),
              SizedBox(width: 16.0),
              Expanded(
                child: Text(
                  'Choose where your voice notes should be saved by connecting your Notion account.',
                  style: TextStyle(fontSize: 14.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Center(
            child: FilledButton(
              onPressed: () {
                ref
                    .read(routerProvider.notifier)
                    .go(Screen.settingsSetupIntegration);
              },
              child: const Text(
                'Connect to Notion',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
