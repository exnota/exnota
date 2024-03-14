import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/connectivity_checker.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ConnectionListener extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectionListener({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<ConnectionListener> createState() => _ConnectionListenerState();
}

class _ConnectionListenerState extends ConsumerState<ConnectionListener> {
  final _log = Logger(context: 'ConnectionListener');
  ConnectivityChecker? _connectivityChecker;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');

    final connStatus = ref.read(connectionStatusProvider);
    _log.debug('Initial connection status: $connStatus');
    _handleConnectionStatusChange(nextStatus: connStatus);
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    _connectivityChecker?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');

    ref.listen(connectionStatusProvider, (prevStatus, nextStatus) {
      _log.debug(
          'ConnectionStatus listener: Changed from $prevStatus -> $nextStatus');
      _handleConnectionStatusChange(nextStatus: nextStatus);
    });

    ref.listen(activeUserIdSyncProvider, (prevUserId, nextUserId) {
      _log.debug(
          'ActiveUserId listener: Changed from $prevUserId -> $nextUserId');

      // Logout
      if (nextUserId == null) {
        _log.debug('ActiveUserId listener: Stopping any connectivity checker');
        _connectivityChecker?.stop();
        return;
      }

      // Login
      if (prevUserId == null) {
        final status = ref.read(connectionStatusProvider);
        if (status == ConnStatus.unauthenticated) {
          // User is likely online after logging in, so reset to that. This will
          // trigger the listener to re-create the checker.
          _log.debug(
              'ActiveUserId listener: Resetting connection status to online');
          ref.read(connectionStatusProvider.notifier).setOnline();
        } else {
          // Re-create the checker as it was stopped on logout.
          _log.debug(
              'ActiveUserId listener: Triggering creation of connectivity checkers.');
          _handleConnectionStatusChange(nextStatus: status);
        }
        return;
      }
    });

    return widget.child;
  }

  void _handleConnectionStatusChange({required ConnStatus nextStatus}) {
    switch (nextStatus) {
      case ConnStatus.offline:
        _log.debug('Handling transition to offline');

        _log.debug('Cleaning up');
        _connectivityChecker?.stop();

        _log.debug('Starting connectivity check');
        setState(() {
          _connectivityChecker = ConnectivityChecker(
            strategy: CheckerStrategy.unlimitedRetry(
              maxInterval: 60,
              onOnline: () {
                ref.read(connectionStatusProvider.notifier).setOnline();
              },
            ),
            uri: ref.read(urlSyncProvider('/api/health')),
            client: http.Client(),
            label: 'offline',
          );
        });
        _connectivityChecker?.start();
        break;

      case ConnStatus.online:
        _log.debug('Handling transition to online');

        _log.debug('Cleaning up');
        _connectivityChecker?.stop();

        _log.debug('Starting server connection');
        setState(() {
          // Create a blank/emptubscription to the server-side event stream of
          // PocketBase. This uses an internal class from the pocketbase package
          // because the official API doesn't expose an onError callback: it just
          // silently fails when the connection is lost.
          //
          // Source: https://github.com/pocketbase/pocketbase/discussions/1957#discussioncomment-5177865
          _connectivityChecker = ConnectivityChecker(
              strategy: CheckerStrategy.detectOffline(
                interval: 20,
                onOffline: () {
                  ref.read(connectionStatusProvider.notifier).setOffline();
                },
              ),
              uri: ref.read(urlSyncProvider('/api/health')),
              client: http.Client(),
              label: 'online');
        });
        _connectivityChecker?.start();
        break;

      case ConnStatus.userRetry:
        _log.debug('Handling transition to userRetry');

        _log.debug('Cleaning up');
        _connectivityChecker?.stop();

        _log.debug('Starting healthcheck retry for userRetry status');
        setState(() {
          _connectivityChecker = ConnectivityChecker(
            strategy: CheckerStrategy.durationRetry(
              maxDuration: 11, // Two 5s timeouts + 1s buffer = 2 attempts
              onOnline: () {
                ref.read(connectionStatusProvider.notifier).setOnline();
              },
              onExpire: () {
                ref.read(connectionStatusProvider.notifier).setOffline();
              },
            ),
            uri: ref.read(urlSyncProvider('/api/health')),
            client: http.Client(),
            label: 'userRetry',
          );
        });
        _connectivityChecker?.start();
        break;

      case ConnStatus.unauthenticated:
        _log.debug('Handling transition to unauthenticated');

        _log.debug('Cleaning up');
        _connectivityChecker?.stop();
        break;
    }
  }
}
