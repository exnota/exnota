import 'package:exnota/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

Future<void> initCrashlytics() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> report(
    {required String description, Object? nonPrivateData}) async {
  if (nonPrivateData != null) {
    await FirebaseCrashlytics.instance.recordError(null, StackTrace.current,
        reason: description, information: [nonPrivateData]);
    return;
  }
  await FirebaseCrashlytics.instance
      .recordError(null, StackTrace.current, reason: description);
}
