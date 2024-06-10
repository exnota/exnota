import 'package:exnota/firebase_options.dart';
import 'package:exnota/src/context/app/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> initCrashlytics(GlobalKey<NavigatorState> navigator) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // final navigator = GlobalKey<NavigatorState>();
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
    print(navigatorKey);
    // navigator.currentState!.push(MaterialPageRoute(builder: (context) {
    //   // standard build method, return your dialog widget
    //   return SimpleDialog(children: [Text(errorDetails.exception.toString())]);
    // }));
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Basic dialog title'),
          content: const Text(
            'A dialog is a type of modal window that\n'
            'appears in front of app content to\n'
            'provide critical information, or prompt\n'
            'for a decision to be made.',
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Disable'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Enable'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> report(
    {required String description, Object? nonPrivateData}) async {
  // Crashlytics is not available in unit tests
  if (Firebase.apps.isEmpty) {
    return;
  }

  if (nonPrivateData != null) {
    await FirebaseCrashlytics.instance.recordError(null, StackTrace.current,
        reason: description, information: [nonPrivateData]);
    return;
  }
  await FirebaseCrashlytics.instance
      .recordError(null, StackTrace.current, reason: description);
}
