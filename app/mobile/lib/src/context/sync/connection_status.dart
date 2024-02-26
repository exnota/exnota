import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection_status.g.dart';

enum ConnStatus { online, offline, userRetry, unauthenticated }

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Context loader providers
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Private providers.
// ----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class ConnectionStatus extends _$ConnectionStatus {
  @override
  ConnStatus build() {
    return ConnStatus.online;
  }

  void setOnline() {
    state = ConnStatus.online;
  }

  void setOffline() {
    state = ConnStatus.offline;
  }

  void setUserRetry() {
    if (state == ConnStatus.online) {
      return;
    }
    state = ConnStatus.userRetry;
  }

  void setUnauthenticated() {
    state = ConnStatus.unauthenticated;
  }
}
