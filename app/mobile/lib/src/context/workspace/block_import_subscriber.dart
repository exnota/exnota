import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/context/workspace/block_importer.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asynchronously imports blocks on load or user change.
///
/// TODO: Subscribe to workspace information
/// TODO: Imports blocks for workspaces
class BlockImportSubscriber extends ConsumerStatefulWidget {
  final Widget child;

  const BlockImportSubscriber({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<BlockImportSubscriber> createState() =>
      _BlockImportSubscriberState();
}

class _BlockImportSubscriberState extends ConsumerState<BlockImportSubscriber> {
  final Logger _log = Logger(context: 'BlockImportSubscriber');
  Future<void> Function()? _unsub;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
    // TODO: #40 Load based on workspaces (1-n), not users.
    final activeUserId = ref.read(activeUserIdProvider);
    if (activeUserId != null) {
      _log.debug('Subscribing to blocks for user: $activeUserId');
      _subscribe();
    }
  }

  @override
  void dispose() {
    _log.debug('Disposing');

    // Can't unsubscribe here because `ref` is not available:  https://github.com/rrousselGit/riverpod/issues/2538
    //
    // Doesn't seem to be an issue in practice because this widget is only
    // disposed when the environment changes, which also disposes the
    // PocketBase provider and, I assume, subscriptions are cleaned up by
    // PocketBase internally, or garbage collected.

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');

    // Subscribe/unsubscribe to block changes when the user logs in/out.
    ref.listen(activeUserIdProvider, (oldActiveUserId, newActiveUserId) async {
      _log.debug(
          'Detected active user ID change from $oldActiveUserId to $newActiveUserId');
      // When a user logs in, import blocks.
      if (oldActiveUserId == null && newActiveUserId != null) {
        _log.debug('Subscribing to blocks for user: $newActiveUserId');
        await _subscribe();
      } else if (oldActiveUserId != null && newActiveUserId == null) {
        _log.debug('Unsubscribing from blocks for user: $oldActiveUserId');
        await _unsubscribe();
      } else if (oldActiveUserId != newActiveUserId) {
        _log.warn('User change not handled');
      } else {
        _log.debug('Skip subscribing request');
      }
    });

    // Stop/resume subscription when connection status changes.
    //
    // PocketBase's realtime subscription will not error or provide any
    // indication when it loses connection to the server, AND it will not
    // recover when the server is back (if it's down longer than 10sec or so).
    // So we need to listen to the connection status and resubscribe when it's
    // back online.
    ref.listen(connectionStatusProvider, (oldStatus, newStatus) async {
      _log.debug(
          'Detected connection status change from $oldStatus to $newStatus');
      switch (newStatus) {
        case ConnStatus.offline:
        case ConnStatus.unauthenticated:
          _log.debug('Unsubscribing due to connection change.');
          await _unsubscribe();
          break;
        case ConnStatus.online:
          _log.debug('Subscribing due to connection change.');
          await _subscribe();
          break;
        case ConnStatus.userRetry:
          _log.debug('No change to subscription due to connection change.');
          break;
      }
    });

    return widget.child;
  }

  Future<void> _subscribe() async {
    _log.debug('Subscribing');
    final pb = ref.read(pocketBaseProvider);

    final unsub =
        await pb.collection(collectionBlock).subscribe('*', (e) async {
      _log.debug(
          'Received \'${e.action}\' action for block record ${e.record?.id}');
      await ref.read(blockImporterProvider.notifier).import(e.record);
    });
    setState(() {
      _unsub = unsub;
    });
  }

  Future<void> _unsubscribe() async {
    _log.debug('Unsubscribing');
    await _unsub!();
    setState(() {
      _unsub = null;
    });
  }
}
