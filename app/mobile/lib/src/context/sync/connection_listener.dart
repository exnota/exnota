// stateful consumer widget ConnectionListener with usual logs

import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/health_check_retry.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
// ignore: implementation_imports
import "package:pocketbase/src/sse/sse_client.dart";

class ConnectionListener extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectionListener({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<ConnectionListener> createState() => _ConnectionListenerState();
}

class _ConnectionListenerState extends ConsumerState<ConnectionListener> {
  final _log = Logger(context: 'ConnectionListener');
  HealthCheckRetry? _healthCheckRetry;
  SseClient? _sseClient;

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
    _sseClient?.close();
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
    if (nextStatus == ConnStatus.offline) {
      _log.debug('Handling transition to offline');

      _log.debug('Cleaning up');
      _healthCheckRetry?.stop();
      _sseClient?.close();

      _log.debug('Starting healthcheck retry');
      setState(() {
        _healthCheckRetry = HealthCheckRetry(
          client: http.Client(),
          uri: ref.read(urlProvider('/api/health')),
          maxDelay: 60,
          onSuccess: () {
            ref.read(connectionStatusProvider.notifier).setOnline();
          },
        );
      });
      _healthCheckRetry?.start();
      return;
    }

    if (nextStatus == ConnStatus.online) {
      _log.debug('Handling transition to online');

      _log.debug('Cleaning up');
      _healthCheckRetry?.stop();

      _log.debug('Starting blank subscription');
      var errorCount = 0;
      setState(() {
        // Example from https://github.com/pocketbase/pocketbase/discussions/1957#discussioncomment-5177865
        _sseClient = SseClient(
          ref.read(urlProvider('/api/realtime')).toString(),
          onError: (err) {
            _log.debug('Blank subscription error with error object: $err');

            // onError can be called multiple times in quick succession. To
            // minimise unexpected race conditions, call setOffline only once.
            errorCount++;
            if (errorCount == 1) {
              ref.read(connectionStatusProvider.notifier).setOffline();
            }
          },
        );
      });
    }
  }
}
