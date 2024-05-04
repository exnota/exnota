import 'package:exnota/src/context/app/app_context_loader.dart';
import 'package:exnota/src/context/sync/sync_context_loader.dart';
import 'package:exnota/src/context/user/user_context_loader.dart';
import 'package:exnota/src/context/workspace/workspace_context_loader.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/new_app_loaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Widget that configures your application.
class MyApp extends ConsumerStatefulWidget {
  const MyApp({
    super.key,
  });

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final Logger _log = Logger(context: 'MyApp');
  bool syncCommandRunnerStarted = false;

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
    // if (!syncCommandRunnerStarted) {
    //   // TODO: Do we need a way to dispose/stop this?
    //   ref.read(syncCommandRunnerProvider.notifier).run();
    //   setState(() {
    //     syncCommandRunnerStarted = true;
    //   });
    // }

    // Context widgets represent the dependency flow:
    // - Outer context widgets and providers should not depend on inner ones.
    //   This includes referencing them or making changes to them. Instead, they
    //   can change their state and inner widgets and providers can react to
    //   those changes.
    //
    // - Outer context widgets and providers should ensure any async and
    //   blocking state has been initialized before rendering their children,
    //   and provide synchronous access to that state.
    //
    // Supporting isolates:
    // - In the future we will spawn foreground isolates and background isolates
    //   may be triggered for actions like home screen widgets.
    // - At time of writing, we constructed everything with providers which are
    //   more intended for the main (UI) isolate. Providers don't share state
    //   across isolates so you cant react to changes initiated in another one.
    // - To avoid big re-writes of logic to decouple them from providers, and to
    //   instead be able to re-use them (carefully) in non-main isolates:
    //   - The non-main isolates need to be able to `await` the user context
    //     providers and have them in turn `await` their own dependencies, etc.
    //   - This is how providers usually work, but for simplicity we previously
    //     had the user context layer assume the environment layer providers
    //     were loaded.
    //   - Instead, we've added explicit sync providers (with 'sync' in the
    //     name) that can be used on inner layers in this main isolate's widget
    //     tree. This avoids needing to check each provider to see if they're
    //     loaded.
    //
    // Other context layers:
    // - Device layer is loaded in main.dart
    // - Environment layer is now loaded in User Context layer implicitly as
    //   part of its chain of dependencies. See above.
    //
    // UserContext is used in this main (UI) isolate, and in other isolates.
    return UserContextLoader(
      child: NewAppLoaders(
        child: SyncContextLoader(
          child: WorkspaceContextLoader(
            child: AppContextLoader(
              builder: (context, themeMode, goRouter) {
                return MaterialApp.router(
                  // Providing a restorationScopeId allows the Navigator built by the
                  // MaterialApp to restore the navigation stack when a user leaves and
                  // returns to the app after it has been killed while running in the
                  // background.
                  restorationScopeId: 'app',

                  // Provide the generated AppLocalizations to the MaterialApp. This
                  // allows descendant Widgets to display the correct translations
                  // depending on the user's locale.
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en', ''), // English, no country code
                  ],

                  // Use AppLocalizations to configure the correct application title
                  // depending on the user's locale.
                  //
                  // The appTitle is defined in .arb files found in the localization
                  // directory.
                  onGenerateTitle: (BuildContext context) =>
                      AppLocalizations.of(context)!.common_appTitle,

                  theme: ThemeData(useMaterial3: true),
                  darkTheme: ThemeData.dark(useMaterial3: true),
                  themeMode: themeMode,
                  routerConfig: goRouter,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
