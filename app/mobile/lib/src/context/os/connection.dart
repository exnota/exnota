import 'package:connectivity_plus/connectivity_plus.dart' as conn_plus;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection.g.dart';

enum ConnectionState { online, offline }

@riverpod
bool isOffline(IsOfflineRef ref) {
  return ref.watch(connectionInternalProvider).requireValue ==
      ConnectionState.offline;
}

@riverpod
ConnectionState connection(ConnectionRef ref) {
  return ref.watch(connectionInternalProvider).requireValue;
}

@Riverpod(keepAlive: true)
class ConnectionInternal extends _$ConnectionInternal {
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
