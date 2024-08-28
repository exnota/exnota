import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:exnota/src/account/user/screen/login_screen.dart';
import 'package:exnota/src/block/screen/setup_destination_screen.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/integration/screen/setup_integration_screen.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/screen/block_list_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

/// Allows navigating to a screen when the router may not have been initialized
/// yet, but either setting the initial value or pushing it if the router
/// exists.
///
/// Bug: You can't press the back button if the screen was set as the initial
/// screen. GoRouter apparently doesn't support stacking multiple screens which
/// would be a solution (i.e. push Notes then the initialized screen so the back
/// button goes back to Notes).
@Riverpod(keepAlive: true)
class InitializeOrPushscreen extends _$InitializeOrPushscreen {
  final Logger _log = Logger(context: 'InitializeOrPushscreen');
  Screen? _initial;

  @override
  void build() {
    // no-op
  }

  void initOrPush(Screen screen) {
    if (ref.exists(routerProvider)) {
      _log.debug('Router exists, pushing screen: $screen');
      ref.read(routerProvider.notifier).push(screen);
    } else {
      _log.debug('Router does not exist, initializing with screen: $screen');
      _initial = screen;
      // ref.read(initialScreenProvider.notifier).set(screen);
    }
  }

  Screen? popInitialScreen() {
    final initial = _initial;
    _initial = null;
    return initial;
  }
}

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
    // This isn't intended to be reactive. It's just a one-time setup.
    final initialScreen =
        ref.read(initializeOrPushscreenProvider.notifier).popInitialScreen() ??
            Screen.home;

    final initialHasActiveUser = ref.read(hasActiveUserSyncProvider);
    final loginStatus = RouterLoginStatus(active: initialHasActiveUser);
    ref.listen(hasActiveUserSyncProvider, (bool? oldActive, bool newActive) {
      _log.debug('Updating login active state to: $newActive');
      loginStatus.active = newActive;
    });

    final router = GoRouter(
        initialLocation: to(initialScreen),
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(
            path: _routeHome,
            builder: (context, state) => const BlockListScreen(),
            routes: [
              GoRoute(
                path: _routeLogin,
                builder: (context, state) => const LoginScreen(),
              ),
              GoRoute(
                  path: _routeSettings,
                  builder: (context, state) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                        path: _routeSettingsSetupIntegration,
                        builder: (context, state) {
                          final forceReauthParam =
                              state.uri.queryParameters['forceReauth'] ??
                                  ''; // may be null
                          return SetupIntegrationScreen(
                            forceReauth: forceReauthParam == 'true',
                          );
                        }),
                    GoRoute(
                      path: _routeSettingsSetupDestination,
                      builder: (context, state) {
                        final integrationID =
                            state.uri.queryParameters['integrationID']!;
                        return SetupDestinationScreen(
                            integrationID: integrationID);
                      },
                    ),
                  ]),
            ],
          ),
        ],
        // Ensure the router is updated when login status changes.
        refreshListenable: loginStatus,
        debugLogDiagnostics: true,
        redirect: (buildContext, state) async {
          _log.debug('Redirecting location: ${state.matchedLocation}');

          if (!loginStatus.active) {
            return to(Screen.login);
          }

          if (state.matchedLocation == '/') {
            return to(Screen.home);
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

  void pop() {
    _log.debug('Popping');
    state.pop();
  }

  void pushReplacement(Screen screen, {Map<String, dynamic>? params}) {
    _log.debug('Pushing replacement screen: $screen');
    final uri = Uri(
      path: to(screen),
      queryParameters: params,
    );
    state.pushReplacement(uri.toString());
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
  home, // notes/blocks screen
  settings,
  settingsSetupIntegration,
  settingsSetupIntegrationForceReauth,
  settingsSetupDestination,
  login,
}

const _routeHome = '/';
const _routeSettings = 'settings';
const _routeSettingsSetupWorkspace = 'setup-workspace';
const _routeSettingsSetupIntegration = 'setup-integration';
const _routeSettingsSetupDestination = 'setup-destination';
const _routeLogin = 'login';

/// BuildContext helper, for getting a route string.
///
/// E.g. `context.push(to(Screen.settings));`
String to(Screen route) {
  switch (route) {
    case Screen.home:
      return _routeHome;
    case Screen.settings:
      Uri uri = Uri(pathSegments: [_routeSettings]);
      return '/$uri';
    case Screen.settingsSetupIntegration:
      Uri uri =
          Uri(pathSegments: [_routeSettings, _routeSettingsSetupIntegration]);
      return '/$uri';
    case Screen.settingsSetupIntegrationForceReauth:
      Uri uri = Uri(
          pathSegments: [_routeSettings, _routeSettingsSetupIntegration],
          queryParameters: {'forceReauth': 'true'});
      return '/$uri';
    case Screen.settingsSetupDestination:
      Uri uri =
          Uri(pathSegments: [_routeSettings, _routeSettingsSetupDestination]);
      return '/$uri';
    case Screen.login:
      Uri uri = Uri(pathSegments: [_routeLogin]);
      return '/$uri';
  }
}
