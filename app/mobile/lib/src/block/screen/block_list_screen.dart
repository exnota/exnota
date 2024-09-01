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
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exnota/src/block/service/block_lister.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:shimmer/shimmer.dart';

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
              final status = data[index].status;

              final ListBlockStatus exportStatus;
              switch (status) {
                case BlockStatus.waiting:
                  exportStatus = ListBlockStatus.device;
                case BlockStatus.syncing:
                case BlockStatus.synced:
                case BlockStatus.transcribing:
                case BlockStatus.error:
                case BlockStatus.unknown:
                  exportStatus = ListBlockStatus.synced;
                case BlockStatus.exported:
                  exportStatus = ListBlockStatus.exported;
              }

              return VoiceNoteListItem(
                status: exportStatus,
                userCreated: block.userCreated,
                title: block.title ?? '',
                transcription: block.audio?.transcription?.join(' ') ?? '',
                exportUrl: block.external?.url,
              );
            },
          ),
        );
      },
    );
  }
}

enum ListBlockStatus { device, synced, exported }

class VoiceNoteListItem extends ConsumerWidget {
  final String title;
  final String transcription;
  final DateTime userCreated;
  final ListBlockStatus status;
  final String? exportUrl;

  const VoiceNoteListItem({
    Key? key,
    required this.title,
    required this.transcription,
    required this.userCreated,
    required this.status,
    required this.exportUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connStatus = ref.watch(connectionStatusProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: title.isNotEmpty
                      ? Text(
                          title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        )
                      : Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            enabled: true,
                            child: const TitlePlaceholder(height: 16),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                ListBlockStatusIcon(
                    status: status,
                    exportUrl: exportUrl,
                    connStatus: connStatus),
              ],
            ),
            const SizedBox(height: 8),
            transcription.isNotEmpty
                ? Text(
                    transcription,
                    style: const TextStyle(color: Colors.black54),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  )
                : Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    enabled: true,
                    child: const TitlePlaceholder(height: 13, rows: 2),
                  ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Timeago(
                builder: (_, value) => Text(value,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                date: userCreated,
                allowFromNow: true,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TitlePlaceholder extends StatelessWidget {
  // final double width;
  final double height;
  final int rows;

  const TitlePlaceholder({
    Key? key,
    // required this.width,
    required this.height,
    this.rows = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(rows, (index) {
        return Column(
          children: [
            Container(
              width: double.infinity,
              height: height,
              color: Colors.white,
            ),
            if (index < rows - 1) const SizedBox(height: 8.0),
          ],
        );
      }),
    );
  }
}

class ListBlockStatusIcon extends StatelessWidget {
  const ListBlockStatusIcon({
    super.key,
    required this.status,
    required this.exportUrl,
    required this.connStatus,
  });

  final ListBlockStatus status;
  final String? exportUrl;
  final ConnStatus connStatus;

  @override
  Widget build(BuildContext context) {
    // This handles the case where a block gets stuck in BlockStatus.syncing
    // status, which I believe happens when attempting to record when offline
    // but before the app knows its offline. It starts the sync attempt and then
    // just stays in that state.
    //
    // Whereas a recording that is created after the app knows it's offline will
    // stay in BlockStatus.waiting status.

    switch (status) {
      case ListBlockStatus.device:
        // Same as offline status above
        return Icon(Icons.cloud_off, color: Theme.of(context).primaryColor);
      case ListBlockStatus.synced:
        if (connStatus == ConnStatus.offline) {
          return Icon(Icons.cloud_off, color: Theme.of(context).primaryColor);
        }
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
        );
      case ListBlockStatus.exported:
        return GestureDetector(
          onTap: () {
            launchUrl(Uri.parse(exportUrl!));
          },
          child: Icon(Icons.open_in_new, color: Theme.of(context).primaryColor),
        );
      default:
        return const SizedBox();
    }
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
