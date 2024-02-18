import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/screen/block_list_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'route.g.dart';

enum Screen {
  notes,
  settings,
}

const routeNotes = '/notes';
const routeSettings = '/settings';

String to(Screen route) {
  switch (route) {
    case Screen.notes:
      return routeNotes;
    case Screen.settings:
      return routeSettings;
  }
}

// This is super important - otherwise, we would throw away the whole widget tree when the provider is updated.
final navigatorKey = GlobalKey<NavigatorState>();

// Source: https://github.com/flutter/flutter/issues/112915
// Another reference repo: https://github.com/lucavenir/go_router_riverpod/blob/master/example/lib/router/router.dart
@Riverpod(keepAlive: true)
class RouterService extends _$RouterService {
  final Logger _log = Logger(context: 'RouterService');

  @override
  GoRouter build() {
    _log.debug('Building router');
    final router = GoRouter(
        initialLocation: routeNotes,
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(
            path: routeNotes,
            builder: (context, state) => const BlockListScreen(),
          ),
          GoRoute(
            path: routeSettings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
        redirect: (buildContext, state) async {
          if (state.matchedLocation == '/') {
            return '/notes';
          }
          return null;
        });
    return router;
  }

  void refresh() {
    _log.debug('Refreshing router');
    ref.invalidateSelf();
  }
}
