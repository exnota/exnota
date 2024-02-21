import 'package:exnota/src/context/user/import_queue.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

/// Asynchronously imports blocks on load or user change.
///
/// TODO: Loads workspace information
/// TODO: Imports blocks for workspaces
class BlockImporter extends ConsumerStatefulWidget {
  final Widget child;

  const BlockImporter({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<BlockImporter> createState() => _BlockImporterState();
}

class _BlockImporterState extends ConsumerState<BlockImporter> {
  final Logger _log = Logger(context: 'BlockImporter');

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
    // TODO: #40 Load based on workspaces (1-n), not users.
    final hasActiveUser = ref.read(hasActiveUserProvider);
    if (hasActiveUser) {
      final userId = ref.read(activeUserIdProvider);
      _log.debug('Importing blocks for user: $userId');
      // Need to wrap in Future to avoid provider throwing an error that its
      // state was modified during the widget's lifecycle.
      Future(() {
        ref
            .read(importQueueProvider.notifier)
            .addRequest(ImportBlocksRequest());
      });
    }
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Import blocks when the active user changes.
    ref.listen(hasActiveUserProvider, (didHaveActiveUser, nowHasActiveUser) {
      if (didHaveActiveUser == null) {
        // Initial import handled in initState
        _log.debug('Skipping import on initial load within ref.listen');
        return;
      }

      // Handle non-active to active transition.
      if (!didHaveActiveUser && nowHasActiveUser) {
        final userId = ref.read(activeUserIdProvider);
        _log.debug('Importing blocks for user: $userId');
        ref
            .read(importQueueProvider.notifier)
            .addRequest(ImportBlocksRequest());
      } else {
        _log.debug(
            'Skipping import where active user goes from $didHaveActiveUser to $nowHasActiveUser');
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
  final _log = Logger(context: 'ImportBlocks');

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('Importing blocks...');

    final result = await pb.collection('block').getFullList(sort: '-created');
    _log.debug('Fetched ${result.length} blocks');

    // Don't use a transaction. If only one import fails, we don't want to
    // block the rest.
    // final repo = ref.read(blockRepoProvider);
    for (final record in result) {
      // TODO: Upsert
      _log.debug('Upserting block ${record.id}');
    }

    _log.debug('Importing blocks complete');
  }
}
