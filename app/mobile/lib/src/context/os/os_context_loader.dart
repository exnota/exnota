import 'package:exnota/src/context/lib/provider.dart';
import 'package:exnota/src/context/os/connection.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders its child once OS-level context providers have been initialized.
class OsContextLoader extends ConsumerStatefulWidget {
  final Widget child;

  const OsContextLoader({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<OsContextLoader> createState() => _OsContextLoaderState();
}

class _OsContextLoaderState extends ConsumerState<OsContextLoader> {
  final Logger _log = Logger(context: 'OsContextLoader');
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
    _listener = AppLifecycleListener(
      onResume: () {
        _log.debug('App resumed');
        _refreshConnectionState();
      },
    );
  }

  @override
  void didUpdateWidget(OsContextLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _log.debug('Updating');
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionLoadingStatusProvider);

    switch (connection) {
      case ProviderLoadingStatus.loading:
        _log.debug('Loading connection state');
        return const Directionality(
            textDirection: TextDirection.ltr,
            child: CircularProgressIndicator());
      case ProviderLoadingStatus.error:
        _log.debug('Connection state error');
        return const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('Error configuring network.'));
      case ProviderLoadingStatus.loaded:
        _log.debug('Connection state loaded');
        return widget.child;
    }
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    _listener.dispose();
    super.dispose();
  }

  Future<void> _refreshConnectionState() async {
    _log.debug('Refreshing connection state');
    ref.read(connectionProvider.notifier).refresh();
  }
}
