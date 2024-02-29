import 'package:exnota/src/context/sync/connectivity_checker.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'connection_status.g.dart';
part 'connection_status.freezed.dart';

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
    ref.onDispose(() {
      _log.debug('Disposing');
    });
    return ref.watch(_connectionStatusInternalProvider).status;
  }

  void setOnline() {
    return ref.read(_connectionStatusInternalProvider.notifier).setOnline();
  }

  void setOffline() {
    return ref.read(_connectionStatusInternalProvider.notifier).setOffline();
  }

  void setUserRetry() {
    return ref.read(_connectionStatusInternalProvider.notifier).setUserRetry();
  }

  void setUnauthenticated() {
    return ref
        .read(_connectionStatusInternalProvider.notifier)
        .setUnauthenticated();
  }

  /// Returns the current connection status, if it has been set since it was
  /// defaulted to 'online'. Or pings the server to check the status, then sets
  /// and returns that value.
  Future<ConnStatus> getNonDefaultStatus() async {
    return await ref
        .read(_connectionStatusInternalProvider.notifier)
        .getNonDefaultStatus();
  }
}

// ----------------------------------------------------------------------------
// Private providers.
// ----------------------------------------------------------------------------

@freezed
class _ConnDetails with _$ConnDetails {
  const factory _ConnDetails({
    required ConnStatus status,
    // `true` if the status has been initialized via a method on the provider.
    //
    // Needed because the status is optimistically initialized as `online`, but
    // some usages may want to know with more confidence that the status has
    // been checked before performing some action.
    required bool isDefault,
  }) = __ConnDetails;
}

/// Internal-only to hide the `initialized` field from the public API, as it's
/// only needed internally.
@Riverpod(keepAlive: true)
class _ConnectionStatusInternal extends _$ConnectionStatusInternal {
  final _log = Logger(context: 'ConnectionStatusInternal');

  @override
  _ConnDetails build() {
    _log.debug('Building');
    ref.onDispose(() {
      _log.debug('Disposing');
    });

    _log.debug('Defaulting to online');
    return const _ConnDetails(
      status: ConnStatus.online,
      isDefault: true,
    );
  }

  void setOnline() {
    _log.debug('Setting online');
    state = const _ConnDetails(
      status: ConnStatus.online,
      isDefault: false,
    );
  }

  void setOffline() {
    _log.debug('Setting offline');
    state = const _ConnDetails(
      status: ConnStatus.offline,
      isDefault: false,
    );
  }

  void setUserRetry() {
    if (state.status == ConnStatus.online) {
      _log.warn('Already online. Skipping setUserRetry');
      return;
    }
    _log.debug('Setting userRetry');
    state = const _ConnDetails(
      status: ConnStatus.userRetry,
      isDefault: false,
    );
  }

  void setUnauthenticated() {
    _log.debug('Setting unauthenticated');
    state = const _ConnDetails(
      status: ConnStatus.unauthenticated,
      isDefault: false,
    );
  }

  /// Returns the current connection status, if it has been set since it was
  /// defaulted to 'online'. Or pings the server to check the status, then sets
  /// and returns that value.
  Future<ConnStatus> getNonDefaultStatus() async {
    _log.debug('getNonDefaultStatus: Start');
    if (!state.isDefault) {
      _log.debug('getNonDefaultStatus: Already initialized');
      return state.status;
    }

    _log.debug('getNonDefaultStatus: Checking status');
    final checker = ConnectivityChecker(
      strategy: CheckerStrategy.fixedRetry(
          maxAttempts: 2,
          onOnline: () {
            // Use future instead
          },
          onExpire: () {
            // Use future instead
          }),
      uri: ref.read(urlProvider('/api/health')),
      client: http.Client(),
    );
    final result = await checker.start();
    if (result == ConnectivityCheckerStatus.online) {
      setOnline();
    } else {
      setOffline();
    }
    return state.status;
  }
}
