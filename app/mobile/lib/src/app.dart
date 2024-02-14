import 'package:exnota/src/context/app/app_context.dart';
import 'package:exnota/src/context/app/local_settings.dart';
import 'package:exnota/src/context/os/os_context.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/context/environment/environment.dart';
import 'package:exnota/src/context/app/route.dart';
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

    return OsContext(
      child: EnvironmentContextLoader(
        child: UserContextLoader(
          child: AppContextLoader(
            child: Builder(builder: (context) {
              final themeMode = ref.watch(themeModeServiceProvider);
              final goRouter = ref.watch(routerServiceProvider);

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
            }),
          ),
        ),
      ),
    );
  }
}
