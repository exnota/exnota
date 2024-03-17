import 'dart:async';

import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/network.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/context/workspace/block_importer.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

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
  BlockImportSubscribeRequest? _connectRequest;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
    // TODO: #40 Load based on workspaces (1-n), not users.
    final activeUserId = ref.read(activeUserIdSyncProvider);
    if (activeUserId != null) {
      _log.debug('Will subscribe to blocks for user: $activeUserId');
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
    ref.listen(activeUserIdSyncProvider,
        (oldActiveUserId, newActiveUserId) async {
      _log.debug(
          'Detected active user ID change from $oldActiveUserId to $newActiveUserId');
      // When a user logs in, import blocks.
      if (oldActiveUserId == null && newActiveUserId != null) {
        _log.debug('Will subscribe to blocks for user: $newActiveUserId');
        await _subscribe();
      } else if (oldActiveUserId != null && newActiveUserId == null) {
        _log.debug('Will unsubscribe from blocks for user: $oldActiveUserId');
        await _unsubscribe();
      } else if (oldActiveUserId != newActiveUserId) {
        _log.warn('User change not handled');
      } else {
        _log.debug('Same user, no change to subscription.');
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
          _log.debug('Will unsubscribe due to connection change.');
          await _unsubscribe();
          break;
        case ConnStatus.online:
          _log.debug('Will subscribe due to connection change.');
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
    _log.debug('Subscribe: Start');

    // The pb.collection(..).subscribe() call will hang if it can't reach the
    // server. At this point, the connection status may not have been checked
    // (it's initialized as online), so call getNonDefaultStatus to ensure
    // the connection status has been checked and isn't simply the default
    // 'online' value.
    _log.debug('Subscribe: Checking connection status');
    final status =
        await ref.read(connectionStatusProvider.notifier).getNonDefaultStatus();
    if (status != ConnStatus.online) {
      _log.debug(
          'Subscribe: Skipping subscribe due to connection status: $status');
      return;
    }

    _log.debug('Subscribe: Stopping retrying any existing connection request');
    _connectRequest?.setStopRetrying();
    setState(() {
      _connectRequest = BlockImportSubscribeRequest();
    });

    _log.debug('Subscribe: Submitting request to subscribe');
    await ref.read(requestHandlerProvider.notifier).submit(
          request: _connectRequest!,
          onSuccess: (result) => {
            setState(() {
              _unsub = result;
            }),
          },
          onError: (err) {
            _log.debug('Subscribe: Failed with error: $err');
          },
        );
  }

  Future<void> _unsubscribe() async {
    _log.debug('Unsubscribe: Start');

    _log.debug(
        'Unsubscribe: Stopping retrying any existing connection request');
    _connectRequest?.setStopRetrying();

    _log.debug('Unsubscribe: Unsubscribe from any existing subscription');
    // _unsub can be null if the initial subscribe is skipped due to being
    // offline (or perhaps if there was an error).
    await _unsub?.call();
    setState(() {
      _unsub = null;
    });
    _log.debug('Unsubscribe: Done');
  }
}

class BlockImportSubscribeRequest
    extends HandledRequest<Future<void> Function()> {
  final Logger _log = Logger(context: 'BlockImportSubscribeRequest');
  bool _stopRetrying = false;

  @override
  bool get stopRetrying => _stopRetrying;

  void setStopRetrying() {
    _log.debug('Setting stop retrying.');
    _stopRetrying = true;
  }

  @override
  Future<Future<void> Function()> request(
      {required PocketBase pb, required Ref ref}) async {
    // Unsubscribe to clean up any hanging previous connection attempts.
    //
    // If a subscribe() attempt hangs because, for example, the server is down,
    // RequestHandler will timeout and retry. However, internally to PocketBase
    // the request still seems to be hung.
    //
    // Then when RequestHandler retries, if the previous subscription is not
    // cleared, it will return immediately with the future from the first
    // attempt, which is still hung. So it will seem to have completed and
    // subscribed, but will not be.
    //
    // Unsubscribing first resolves this issue and PocketBase makes a new
    // connection attempt.
    //
    // This may have consequences in the future if we subscribe to the same
    // collection and topic in multiple places. Currently how we subscribe I
    // can't see a way to unsubscribe with a key or some identifier.
    //
    // Two options may be:
    // i. Create a service to handle subs/unsubs that reconnects all for the
    //    same topic.
    // 2. Try using pb.realtime for sub/unsub instead, because that allows
    //    unsubscribing by listener function.
    _log.debug('Clearing previous subscribe attempts');
    await pb.collection(collectionBlock).unsubscribe('*');

    _log.debug('Subscribing to block changes');

    // There's no real error handling for PocketBase subscriptions.
    //
    // The subscribe() call will hang if the server isn't available. That's
    // why we check connection status period to subscribing, to minimize the
    // chance of this happening.
    //
    // No error is thrown if the connection becomes available either, and it
    // doesn't always recover. That's why we refresh it when the connection
    // status changes and run this through RequestHandler to retry.
    // TODO: #40 Pass in the user ID
    final result =
        await pb.collection(collectionBlock).subscribe('*', (e) async {
      _log.debug(
          'Received \'${e.action}\' action for block record ${e.record?.id}');
      await ref.read(blockImporterProvider.notifier).import(e.record);
    });
    _log.debug('Subscribed to block changes');
    return result;
  }
}
