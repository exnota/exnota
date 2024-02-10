import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:exnota/src/account/user/screen/login.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/note/screen/block_list_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'route.g.dart';

enum Screen {
  login,
  notes,
  settings,
}

const routeLogin = '/login';
const routeNotes = '/notes';
const routeSettings = '/settings';

String to(Screen route) {
  switch (route) {
    case Screen.login:
      return routeLogin;
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
@riverpod
class RouterService extends _$RouterService {
  @override
  GoRouter build() {
    final userContext = ref.watch(userContextServiceProvider);

    final router = GoRouter(
        initialLocation: routeNotes,
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(
            path: routeLogin,
            builder: (context, state) => const LoginScreen(),
          ),
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
          // TODO: If navigating to /login but already logged in, we should
          // either redirect elsewhere, or log the user out.
          final active = userContext.userAuth?.active ?? false;
          final valid = userContext.userAuth?.valid ?? false;
          if (!active || !valid) {
            return '/login';
          }

          if (state.matchedLocation == '/') {
            return '/notes';
          }
          return null;
        });
    return router;
  }
}
