import 'package:exnota/src/context/lib/provider.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders its child once user context providers have been initialized.
class UserContextLoader extends ConsumerWidget {
  final Widget child;

  const UserContextLoader({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _UserContextLoader(child: child);
  }
}

class _UserContextLoader extends ConsumerStatefulWidget {
  final Widget child;

  const _UserContextLoader({required this.child});

  @override
  ConsumerState<_UserContextLoader> createState() => _UserContextLoaderState();
}

class _UserContextLoaderState extends ConsumerState<_UserContextLoader> {
  final Logger _log = Logger(context: 'UserContextLoader');

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
    final userContextLoading = ref.watch(userContextLoadingStatusProvider);

    // Directionality is needed because any content rendered here will not be
    // within a MaterialApp instance and throw an error.
    switch (userContextLoading) {
      case ProviderLoadingStatus.loading:
        _log.debug('Loading user context');
        return const Directionality(
            textDirection: TextDirection.ltr,
            child: CircularProgressIndicator());
      case ProviderLoadingStatus.error:
        _log.debug('User context error');
        return Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
                'Error loading user: ${ref.watch(userContextLoadingErrorProvider)}'));
      case ProviderLoadingStatus.loaded:
        _log.debug('User context loaded');
        return widget.child;
    }
  }
}
