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
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');

    // Import all blocks when the active user changes.
    ref.listen(activeUserIdProvider, (oldActiveUserId, newActiveUserId) {
      _log.debug(
          'Detected active user ID change from $oldActiveUserId to $newActiveUserId');
      // When a user logs in, import blocks.
      if (oldActiveUserId == null && newActiveUserId != null) {
        _log.debug('Subscribing to blocks for user: $newActiveUserId');
        _subscribe();
      } else if (oldActiveUserId != null && newActiveUserId == null) {
        _log.debug('Unsubscribing from blocks for user: $oldActiveUserId');
        _unsubscribe();
      } else if (oldActiveUserId != newActiveUserId) {
        _log.warn('User change not handled');
      } else {
        _log.debug('Skip subscribing request');
      }
    });

    return widget.child;
  }

  void _subscribe() {
    _log.debug('Subscribing');
    final pb = ref.read(pocketBaseProvider);
    pb.collection(collectionBlock).subscribe("*", (e) async {
      _log.debug(
          'Received \'${e.action}\' action for block record ${e.record?.id}');
      await ref.read(blockImporterProvider.notifier).import(e.record);
    });
  }

  void _unsubscribe() {
    _log.debug('Unsubscribing');
    final pb = ref.read(pocketBaseProvider);
    pb.collection(collectionBlock).unsubscribe();
  }
}
