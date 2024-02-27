// stateful consumer widget ConnectionListener with usual logs

import 'package:exnota/src/context/sync/connection_status.dart';
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
  HealthCheckRetry? _healthCheckRetry;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');

    ref.listen(connectionStatusProvider, (prevStatus, nextStatus) {
      _log.debug('Connection status changed: $prevStatus -> $nextStatus');
      if (nextStatus == ConnStatus.offline) {
        _log.debug('Handling transition to offline');

        _log.debug('Cleaning up');
        // Cleanup
        _healthCheckRetry?.stop();
        // TODO: Clear blank subscription

        _log.debug('Starting healthcheck retry');
        _healthCheckRetry = HealthCheckRetry(
          client: http.Client(),
          uri: ref.read(urlProvider('/api/health')),
          maxDelay: 60,
          onSuccess: () {
            ref.read(connectionStatusProvider.notifier).setOnline();
          },
        );
        _healthCheckRetry?.start();
      }
    });

    return widget.child;
  }
}
