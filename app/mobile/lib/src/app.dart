import 'package:exnota/src/account/settings/settings_screen.dart';
import 'package:exnota/src/account/settings/settings_service.dart';
import 'package:exnota/src/account/user/screen/login.dart';
import 'package:exnota/src/account/user/service/user_context_service.dart';
import 'package:exnota/src/note/screen/block_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:exnota/src/note/screen/sample_item_details_screen.dart';
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
  bool syncCommandRunnerStarted = false;

  @override
  Widget build(BuildContext context) {
    // if (!syncCommandRunnerStarted) {
    //   // TODO: Do we need a way to dispose/stop this?
    //   ref.read(syncCommandRunnerProvider.notifier).run();
    //   setState(() {
    //     syncCommandRunnerStarted = true;
    //   });
    // }

    return _EagerProviderLoader(
      child: Builder(builder: (context) {
        // Already loaded with _EagerProviderLoader, so safe to use requireValue.
        final settings = ref.watch(settingsServiceProvider).requireValue;

        return MaterialApp(
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
          themeMode: settings.themeMode,

          // Define a function to handle named routes in order to support
          // Flutter web url navigation and deep linking.
          onGenerateRoute: (RouteSettings routeSettings) {
            return MaterialPageRoute<void>(
              settings: routeSettings,
              builder: (BuildContext context) {
                final userContextAsync = ref.watch(userContextServiceProvider);

                return userContextAsync.when(
                  loading: () => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Scaffold(
                    body: Center(
                      child: Text('Error: $error'),
                    ),
                  ),
                  data: (userContext) {
                    final active = userContext.userAuth?.active ?? false;
                    final valid = userContext.userAuth?.valid ?? false;
                    if (!active || !valid) {
                      return const Scaffold(
                        body: Center(child: LoginScreen()),
                      );
                    }

                    switch (routeSettings.name) {
                      case SettingsScreen.routeName:
                        return const SettingsScreen();
                      case SampleItemDetailsScreen.routeName:
                        return const SampleItemDetailsScreen();
                      case BlockListScreen.routeName:
                      default:
                        return const BlockListScreen();
                    }
                  },
                );
              },
            );
          },
        );
      }),
    );
  }
}

class _EagerProviderLoader extends ConsumerWidget {
  const _EagerProviderLoader({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);

    if (settings.isLoading) {
      return const CircularProgressIndicator();
    } else if (settings.hasError) {
      return const Text('Error loading data.');
    }

    return child;
  }
}
