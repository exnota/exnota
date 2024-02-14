import 'package:exnota/src/context/os/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class OsContext extends ConsumerStatefulWidget {
  final Widget child;

  const OsContext({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<OsContext> createState() => _OsContextState();
}

class _OsContextState extends ConsumerState<OsContext> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => _refreshConnectionState(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionInternalProvider);

    // Directionality is needed because any content rendered here will not be
    // within a MaterialApp instance and throw an error.
    if (connection.isLoading) {
      return const Directionality(
          textDirection: TextDirection.ltr, child: CircularProgressIndicator());
    } else if (connection.hasError) {
      return const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Error configuring network.'));
    }

    return widget.child;
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  Future<void> _refreshConnectionState() async {
    // ignore: unused_result
    await ref.refresh(connectionInternalProvider.future);
  }
}
