import 'package:connectivity_plus/connectivity_plus.dart' as conn_plus;
import 'package:exnota/src/context/lib/provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection.g.dart';

enum ConnectionState { online, offline }

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

@riverpod
bool isOffline(IsOfflineRef ref) {
  return ref.watch(_connectionInternalProvider).requireValue ==
      ConnectionState.offline;
}

@riverpod
class Connection extends _$Connection {
  @override
  ConnectionState build() {
    return ref.watch(_connectionInternalProvider).requireValue;
  }

  void refresh() {
    ref.read(_connectionInternalProvider.notifier).refresh();
  }
}

// ----------------------------------------------------------------------------
// Context loader providers
// ----------------------------------------------------------------------------

/// Returns the parent provider's loading status and won't refresh when the
/// parents state value changes, so can be used as as part of a guard to ensure
/// the parent provider is loaded.
@riverpod
ProviderLoadingStatus connectionLoadingStatus(ConnectionLoadingStatusRef ref) {
  final userContext = ref.watch(_connectionInternalProvider);
  return userContext.maybeWhen(
    data: (_) => ProviderLoadingStatus.loaded,
    error: (_, __) => ProviderLoadingStatus.error,
    orElse: () => ProviderLoadingStatus.loading,
  );
}

// ----------------------------------------------------------------------------
// Private providers.
// ----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class _ConnectionInternal extends _$ConnectionInternal {
  @override
  Future<ConnectionState> build() async {
    // The connectivity_plus package doesn't check if the internet is actually
    // available. Additional checks might be needed if it's providing false
    // positives.
    final connectivity = conn_plus.Connectivity();
    final result = await (connectivity.checkConnectivity());

    // "Connectivity changes are no longer communicated to Android apps in the
    // background starting with Android O (8.0). You should always check for
    // connectivity status when your app is resumed. The broadcast is only
    // useful when your application is in the foreground."
    final sub = connectivity.onConnectivityChanged
        .listen((conn_plus.ConnectivityResult result) {
      if (result == conn_plus.ConnectivityResult.none) {
        state = const AsyncData(ConnectionState.offline);
      } else {
        state = const AsyncData(ConnectionState.online);
      }
    });
    ref.onDispose(() {
      sub.cancel();
    });

    if (result == conn_plus.ConnectivityResult.none) {
      return ConnectionState.offline;
    }
    return ConnectionState.online;
  }

  void refresh() {
    ref.invalidateSelf();
  }
}
