import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/connectivity_checker.dart';
import 'package:exnota/src/context/sync/health_check_retry.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
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
  // TODO: Remove this when other version is tested
  HealthCheckRetry? _healthCheckRetry;
  ConnectivityChecker? _connectivityChecker;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');

    final connStatus = ref.read(connectionStatusProvider);
    _log.debug('Initial connection status: $connStatus');
    _handleConnectionStatusChange(null, connStatus);
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    _healthCheckRetry?.stop();
    _connectivityChecker?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');

    ref.listen(connectionStatusProvider, (prevStatus, nextStatus) {
      _log.debug('Connection status changed: $prevStatus -> $nextStatus');
      _handleConnectionStatusChange(prevStatus, nextStatus);
    });

    return widget.child;
  }

  void _handleConnectionStatusChange(
      ConnStatus? prevStatus, ConnStatus nextStatus) {
    switch (nextStatus) {
      case ConnStatus.offline:
        _log.debug('Handling transition to offline');

        _log.debug('Cleaning up');
        _healthCheckRetry?.stop();
        _connectivityChecker?.stop();

        _log.debug('Starting healthcheck retry for offline status');
        setState(() {
          _healthCheckRetry = HealthCheckRetry(
            client: http.Client(),
            uri: ref.read(urlProvider('/api/health')),
            label: 'offline',
            maxDelay: 60,
            onSuccess: () {
              ref.read(connectionStatusProvider.notifier).setOnline();
            },
          );
        });
        _healthCheckRetry?.start();
        break;

      case ConnStatus.online:
        _log.debug('Handling transition to online');

        _log.debug('Cleaning up');
        _healthCheckRetry?.stop();
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
              uri: ref.read(urlProvider('/api/health')),
              client: http.Client());
        });
        _connectivityChecker?.start();
        break;

      case ConnStatus.userRetry:
        _log.debug('Handling transition to userRetry');

        _log.debug('Cleaning up');
        _healthCheckRetry?.stop();
        _connectivityChecker?.stop();

        _log.debug('Starting healthcheck retry for userRetry status');
        setState(() {
          _healthCheckRetry = HealthCheckRetry(
            client: http.Client(),
            uri: ref.read(urlProvider('/api/health')),
            label: 'userRetry',
            maxDuration: 10,
            onSuccess: () {
              ref.read(connectionStatusProvider.notifier).setOnline();
            },
            onExpire: () {
              ref.read(connectionStatusProvider.notifier).setOffline();
            },
          );
        });
        _healthCheckRetry?.start();
        break;

      case ConnStatus.unauthenticated:
        _log.debug('Handling transition to unauthenticated');

        _log.debug('Cleaning up');
        _healthCheckRetry?.stop();
        _connectivityChecker?.stop();
        break;
    }
  }
}
