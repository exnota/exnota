// import 'package:exnota/src/context/environment/environment.dart';
// import 'package:exnota/src/context/lib/provider.dart';
// import 'package:exnota/src/lib/log/logger.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders its child once Environment-level context providers have been
/// initialized.
// class EnvironmentContextLoader extends ConsumerStatefulWidget {
//   const EnvironmentContextLoader({super.key, required this.child});
//   final Widget child;

//   @override
//   ConsumerState<EnvironmentContextLoader> createState() =>
//       _EnvironmentContextLoaderState();
// }

// class _EnvironmentContextLoaderState
//     extends ConsumerState<EnvironmentContextLoader> {
//   final Logger _log = Logger(context: 'EnvironmentContextLoader');

//   @override
//   void initState() {
//     super.initState();
//     _log.debug('Initializing');
//   }

//   @override
//   void dispose() {
//     _log.debug('Disposing');
//     super.dispose();
//   }

//   @override
//   void didUpdateWidget(EnvironmentContextLoader oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     _log.debug('Updating');
//   }

//   @override
//   Widget build(BuildContext context) {
//     final environmentLoading = ref.watch(environmentLoadingStatusProvider);

//     // Directionality is needed because any content rendered here will not be
//     // within a MaterialApp instance and throw an error.
//     switch (environmentLoading) {
//       case ProviderLoadingStatus.loading:
//         return const Directionality(
//             textDirection: TextDirection.ltr,
//             child: CircularProgressIndicator());
//       case ProviderLoadingStatus.error:
//         return const Directionality(
//             textDirection: TextDirection.ltr, child: Text('Error'));
//       case ProviderLoadingStatus.loaded:
//         return widget.child;
//     }
//   }
// }
