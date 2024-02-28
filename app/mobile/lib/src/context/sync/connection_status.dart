import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection_status.g.dart';

enum ConnStatus { online, offline, userRetry, unauthenticated }

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class ConnectionStatus extends _$ConnectionStatus {
  final _log = Logger(context: 'ConnectionStatus');

  @override
  ConnStatus build() {
    _log.debug('Building');
    _log.debug('Defaulting to online');
    return ConnStatus.online;
  }

  void setOnline() {
    _log.debug('Setting online');
    state = ConnStatus.online;
  }

  void setOffline() {
    _log.debug('Setting offline');
    state = ConnStatus.offline;
  }

  void setUserRetry() {
    if (state == ConnStatus.online) {
      _log.warn('Already online. Skipping setUserRetry');
      return;
    }
    _log.debug('Setting userRetry');
    state = ConnStatus.userRetry;
  }

  void setUnauthenticated() {
    _log.debug('Setting unauthenticated');
    state = ConnStatus.unauthenticated;
  }
}
