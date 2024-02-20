import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:exnota/src/account/user/screen/login_screen.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/screen/block_list_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

enum Screen {
  notes,
  settings,
  login,
}

const routeNotes = '/notes';
const routeSettings = '/settings';
const routeLogin = '/login';

String to(Screen route) {
  switch (route) {
    case Screen.notes:
      return routeNotes;
    case Screen.settings:
      return routeSettings;
    case Screen.login:
      return routeLogin;
  }
}

class LoginInfo extends ChangeNotifier {
  bool _active = false;
  bool get active => _active;

  LoginInfo({bool active = false}) : _active = active;

  set active(bool value) {
    _active = value;
    notifyListeners();
  }
}

// This is super important - otherwise, we would throw away the whole widget tree when the provider is updated.
final navigatorKey = GlobalKey<NavigatorState>();

// Here are some useful links, because I had some problems getting this working:
//
// Source: https://github.com/flutter/flutter/issues/112915
// Another reference repo: https://github.com/lucavenir/go_router_riverpod/blob/master/example/lib/router/router.dart
// GoRouter with Riverpod: https://github.com/rrousselGit/riverpod/discussions/1357#discussioncomment-7214606
// Official example with deep link redirect support: https://docs.page/csells/go_router/redirection#example-redirection-and-query-parameters
@riverpod
class RouterService extends _$RouterService {
  final Logger _log = Logger(context: 'RouterService');

  @override
  GoRouter build() {
    final initialHasActiveUser = ref.read(hasActiveUserProvider);
    final loginInfo = LoginInfo(active: initialHasActiveUser);
    ref.listen(hasActiveUserProvider, (bool? oldActive, bool newActive) {
      loginInfo.active = newActive;
    });

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
          GoRoute(
            path: routeLogin,
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        // Ensure the router is updated when login state changes.
        refreshListenable: loginInfo,
        debugLogDiagnostics: true,
        redirect: (buildContext, state) async {
          _log.debug('Redirecting location: ${state.matchedLocation}');

          if (!loginInfo.active) {
            return routeLogin;
          }

          if (state.matchedLocation == '/') {
            return routeNotes;
          }
          return null;
        });

    ref.onDispose(() {
      loginInfo.dispose();
      router.dispose();
    });

    return router;
  }

  void go(Screen screen) {
    state.go(to(screen));
  }

  void push(Screen screen) {
    state.push(to(screen));
  }
}
