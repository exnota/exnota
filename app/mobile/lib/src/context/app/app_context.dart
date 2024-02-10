import 'package:exnota/src/context/app/local_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppContextLoader extends ConsumerWidget {
  const AppContextLoader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSettings = ref.watch(localSettingsInternalProvider);
    // routerProvider is not async, so doesn't need eager initialization.

    // Directionality is needed because any content rendered here will not be
    // within a MaterialApp instance and throw an error.
    if (localSettings.isLoading) {
      return const Directionality(
          textDirection: TextDirection.ltr, child: CircularProgressIndicator());
    } else if (localSettings.hasError) {
      print(localSettings.error.toString());
      return const Directionality(
          textDirection: TextDirection.ltr, child: Text('Error loading data.'));
    }

    return child;
  }
}
