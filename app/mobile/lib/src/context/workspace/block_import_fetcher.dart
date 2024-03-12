import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/import_request_queue.dart';
import 'package:exnota/src/context/sync/network.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/context/workspace/block_importer.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

/// Asynchronously imports blocks on load or user change.
///
/// TODO: Loads workspace information
/// TODO: Imports blocks for workspaces
class BlockImportFetcher extends ConsumerStatefulWidget {
  final Widget child;

  const BlockImportFetcher({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<BlockImportFetcher> createState() => _BlockImportFetcherState();
}

class _BlockImportFetcherState extends ConsumerState<BlockImportFetcher> {
  final Logger _log = Logger(context: 'BlockImportFetcher');

  late final AppLifecycleListener _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');

    _appLifecycleListener = AppLifecycleListener(
      onResume: () {
        _log.debug('App resume detected');
        final activeUserId = ref.read(activeUserIdProvider);
        if (activeUserId != null) {
          _log.debug('Adding block import request for user: $activeUserId');
          ref
              .read(importRequestQueueProvider.notifier)
              .addRequest(ImportBlocksRequest());
        } else {
          _log.debug('No active user, skipping block import request');
        }
      },
    );

    // TODO: #40 Load based on workspaces (1-n), not users.
    final activeUserId = ref.read(activeUserIdProvider);
    if (activeUserId != null) {
      _log.debug('Adding block import request for user: $activeUserId');
      // Need to wrap in Future to avoid provider throwing an error that its
      // state was modified during the widget's lifecycle.
      Future(() {
        ref
            .read(importRequestQueueProvider.notifier)
            .addRequest(ImportBlocksRequest());
      });
    } else {
      _log.debug('No active user, skipping block import request');
    }
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    _appLifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');

    // Import all blocks when the active user changes.
    ref.listen(activeUserIdProvider, (oldActiveUserId, newActiveUserId) {
      _log.debug(
          'ActiveUserId listener: Detected change from $oldActiveUserId to $newActiveUserId');
      // When a user logs in, import blocks.
      if (oldActiveUserId == null && newActiveUserId != null) {
        _log.debug('ActiveUserId listener: Queuing block import');
        ref
            .read(importRequestQueueProvider.notifier)
            .addRequest(ImportBlocksRequest());
      } else if (oldActiveUserId != null &&
          newActiveUserId != null &&
          oldActiveUserId != newActiveUserId) {
        _log.warn('ActiveUserId listener: User change not handled');
      } else {
        _log.debug('ActiveUserId listener: Skip block import');
      }
    });

    // Import all blocks when back online
    ref.listen(connectionStatusProvider, (oldStatus, newStatus) {
      _log.debug(
          'Status listener: Detected change from $oldStatus to $newStatus');
      if (oldStatus != ConnStatus.online && newStatus == ConnStatus.online) {
        _log.debug('Status listener: Queuing block import');
        ref
            .read(importRequestQueueProvider.notifier)
            .addRequest(ImportBlocksRequest());
      }
    });

    // TODO: Soon this will load the relevant workspaces that will be used to things
    // like:
    // - Determine which blocks will be fetched.
    // - Determines which destinations will be available for sending new blocks
    //   to.
    //
    // It will depend on userContextProvider. When there is no user, there will
    // be no workspace.
    //
    // When a user logs in workspaceProvider (or some importer) fetch workspaces
    // from the backend (even if there are some locally, they might be
    // outdated).
    //
    // Once loaded, they are pulled from the local database and made available
    // via workspaceProvider, synchronously.
    //
    // In the future, the user may be able to choose which workspace they are
    // working from. This will be done by setting a local_active_workspace
    // entry in the database. This will be used to determine which workspace to
    // pull entries from.
    return widget.child;
  }
}

class ImportBlocksRequest extends ImportRequest<List<RecordModel>> {
  final _log = Logger(context: 'ImportBlocksRequest');

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Importing blocks...');

    final result = await pb
        .collection(collectionBlock)
        .getFullList(sort: '-created')
        // Timeout added because otherwise, if the server goes down, this hangs
        // forever I believe.
        .timeout(defaultTimeout);
    _log.debug('Fetched ${result.length} blocks');

    await ref.read(blockImporterProvider.notifier).importAll(result);

    _log.debug('Importing blocks complete');
  }
}
