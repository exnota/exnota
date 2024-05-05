import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:exnota/src/account/user/screen/login_screen.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/screen/block_list_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

/// GoRouter instance.
///
/// This should not be refreshed except in cases where its okay that the
/// navigation location and history is lost, e.g. when the user logs out.
///
/// This took a while to get right, so here are some useful links:
///
/// - Official GoRouter example with deep link redirect support: https://docs.page/csells/go_router/redirection#example-redirection-and-query-parameters
/// - Riverpod + GoRouter examples:
///   - https://github.com/flutter/flutter/issues/112915
///   - https://github.com/lucavenir/go_router_riverpod/blob/master/example/lib/router/router.dart
///   - https://github.com/rrousselGit/riverpod/discussions/1357#discussioncomment-7214606
@riverpod
class Router extends _$Router {
  final Logger _log = Logger(context: 'Router');

  @override
  GoRouter build() {
    _log.debug('Building');
    final initialHasActiveUser = ref.read(hasActiveUserSyncProvider);
    final loginStatus = RouterLoginStatus(active: initialHasActiveUser);
    ref.listen(hasActiveUserSyncProvider, (bool? oldActive, bool newActive) {
      _log.debug('Updating login active state to: $newActive');
      loginStatus.active = newActive;
    });

    final router = GoRouter(
        initialLocation: _routeNotes,
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(
            path: _routeNotes,
            builder: (context, state) => const BlockListScreen(),
          ),
          GoRoute(
            path: _routeSettings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: _routeLogin,
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        // Ensure the router is updated when login status changes.
        refreshListenable: loginStatus,
        debugLogDiagnostics: true,
        redirect: (buildContext, state) async {
          _log.debug('Redirecting location: ${state.matchedLocation}');

          if (!loginStatus.active) {
            return _routeLogin;
          }

          if (state.matchedLocation == '/') {
            return _routeNotes;
          }
          return null;
        });

    ref.onDispose(() {
      _log.debug('Disposing');
      loginStatus.dispose();
      router.dispose();
    });

    return router;
  }

  /// Navigates to the given screen. To be used when no BuildContext is
  /// available.
  ///
  /// Recommended by https://codewithandrea.com/articles/flutter-navigate-without-context-gorouter-riverpod/
  ///
  /// Apparently an alternate approach is to use NavigatorKey. See https://stackoverflow.com/a/77241743 and https://stackoverflow.com/a/73892010
  void go(Screen screen) {
    _log.debug('Navigating to screen: $screen');
    state.go(to(screen));
  }

  /// Pushes the given screen onto the stack. To be used when no BuildContext is
  /// available.
  ///
  /// Recommended by https://codewithandrea.com/articles/flutter-navigate-without-context-gorouter-riverpod/
  ///
  /// Apparently an alternate approach is to use NavigatorKey. See https://stackoverflow.com/a/77241743 and https://stackoverflow.com/a/73892010
  void push(Screen screen) {
    _log.debug('Pushing screen: $screen');
    state.push(to(screen));
  }
}

/// Login status notifier to pass to GoRouter instance.
class RouterLoginStatus extends ChangeNotifier {
  bool _active = false;
  bool get active => _active;

  RouterLoginStatus({bool active = false}) : _active = active;

  set active(bool value) {
    _active = value;
    notifyListeners();
  }
}

// This is super important - otherwise, we would throw away the whole widget tree when the provider is updated.
final navigatorKey = GlobalKey<NavigatorState>();

// ----------------------------------------------------------------------------
// Public helpers
// ----------------------------------------------------------------------------

enum Screen {
  notes,
  settings,
  login,
}

const _routeNotes = '/notes';
const _routeSettings = '/settings';
const _routeLogin = '/login';

/// BuildContext helper, for getting a route string.
///
/// E.g. `context.push(to(Screen.settings));`
String to(Screen route) {
  switch (route) {
    case Screen.notes:
      return _routeNotes;
    case Screen.settings:
      return _routeSettings;
    case Screen.login:
      return _routeLogin;
  }
}
