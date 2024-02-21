import 'package:exnota/src/context/app/local_settings.dart';
import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/lib/provider.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

typedef BuilderFn = Widget Function(
    BuildContext context, ThemeMode themeMode, GoRouter goRouter);

/// Renders its child once App-level context providers have been initialized.
class AppContextLoader extends ConsumerStatefulWidget {
  const AppContextLoader({super.key, required this.builder});
  final BuilderFn builder;

  @override
  ConsumerState<AppContextLoader> createState() => _AppContextLoaderState();
}

class _AppContextLoaderState extends ConsumerState<AppContextLoader> {
  final Logger _log = Logger(context: 'AppContextLoader');

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
    final localSettingsLoading = ref.watch(localSettingsLoadingStatusProvider);

    // Directionality is needed because any content rendered here will not be
    // within a MaterialApp instance and throw an error.
    return switch (localSettingsLoading) {
      ProviderLoadingStatus.loading => const Directionality(
          textDirection: TextDirection.ltr, child: CircularProgressIndicator()),
      ProviderLoadingStatus.error => const Directionality(
          textDirection: TextDirection.ltr, child: Text('Error loading data.')),
      ProviderLoadingStatus.loaded => Builder(builder: (context) {
          final themeMode = ref.watch(themeModeSettingProvider);
          final goRouter = ref.watch(routerProvider);
          return widget.builder(context, themeMode, goRouter);
        })
    };
  }
}
