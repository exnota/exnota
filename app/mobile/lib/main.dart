import 'dart:isolate';

import 'package:audio_session/audio_session.dart';
import 'package:exnota/src/context/device/device_info.dart';
import 'package:exnota/src/context/device/local_file_path_service.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/lib/log/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

/// A POC for running an isolate that re-uses providers.
Future<void> isolateTest() async {
  // There are a few combinations of isolate we could have in the future:
  //
  // - A main (i.e. UI) isolate, nothing else.
  // - A main isolate that spawns a background/foreground isolate
  //    - Some use cases:
  //       - Record audio in the background on Android.
  //       - Execute a sync command in the background.
  //    - Can use https://pub.dev/packages/flutter_foreground_task
  // - A background isolate without a main isolate
  //    - E.g. a workmanager instance that executes sync commands when the
  //      device comes back online.
  //
  // For providers:
  // - They wont' share state across isolates.
  // - We should still be able to use them in the isolate if we're aware of the
  //   limitations.
  // - So we should:
  //    - Not rely on provider state to be reactive and update.
  //      - E.g. if we're running 5 sync commands in the background, we should
  //        pull the user context at the start of each command manually (maybe
  //        invalidate the provider?), check if it's changed, and if it has
  //        then don't run any more commands.
  //      - For now, this affects: User context, environment (and their URLs).
  //    - Not update state in providers.
  //    - See below regarding updating the database.
  //
  // Regarding using drift databases across isolates, from my research I *think*:
  // - You can use a different DB instance in the main isolate and bg/fg
  //   isolate. However without anything connecting them, any writes in a bg/fg
  //   won't be reflected in the ui of the main isolate without a refresh of
  //   some kind.
  //    - This might be how to do a refresh: https://github.com/simolus3/drift/issues/567#issuecomment-1703872397
  // - There is a technique to get this kinda working, but it may be tricky. See
  //   https://github.com/simolus3/drift/issues/567#issuecomment-934514380
  //
  // Some docs
  // - See 'Independent Isolates' at bottom: https://drift.simonbinder.eu/docs/advanced-features/isolates/#independent-isolates
  // - https://github.com/simolus3/drift/issues/567

  final rootToken = RootIsolateToken.instance;

  // Running a separate isolate will probably be a bit different if we use
  // workmanager or for tasks created via home screen widgets, etc.
  //
  // E.g. we may not need to call BackgroundIsolateBinaryMessenger.ensureInitialized
  await Isolate.run(() {
    final isolateLog = Logger(context: 'isolate');
    isolateLog.debug('Running isolate');
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken!);

    return Future<void>(() async {
      final overrides = await getOverrides();
      final container = ProviderContainer(
        overrides: overrides,
      );

      final userContext =
          await container.read(userContextServiceProvider.future);
      isolateLog.debug(
          'userContext.userAuth?.userId: ${userContext.userAuth?.userId}');
    });
  });
}

void main() async {
  final log = Logger(context: 'main');
  log.debug('Starting main');

  // Needed for the database, Firebase, and more. Don't know why :)
  WidgetsFlutterBinding.ensureInitialized();

  await isolateTest();

  // Recording doesn't seem to work without this
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.record,
  ));

  // Overrides
  final overrides = await getOverrides();

  // TODO: Move sync command runner init to inside the user context
  // (possibly inside a workspace context)
  //
  // Sync command runner
  // await initSyncCommands(overrides: overrides);

  runApp(ProviderScope(overrides: overrides, child: const MyApp()));
}

Future<List<Override>> getOverrides() async {
  final deviceInfo = await initDeviceInfoService();
  await initCrashlytics();
  final localFilePathGenerator = await initLocalFilePathGenerator();
  final db = initDatabase(files: localFilePathGenerator);

  return getOverridesForValues(
    db: db,
    deviceInfo: deviceInfo,
    localFilePathGenerator: localFilePathGenerator,
  );
}

List<Override> getOverridesForValues(
    {required LocalPathGenerator localFilePathGenerator,
    required AppDatabase db,
    required DeviceInfo deviceInfo}) {
  return [
    localFilePathServiceProvider.overrideWithValue(localFilePathGenerator),
    databaseProvider.overrideWithValue(db),
    deviceInfoServiceProvider.overrideWithValue(deviceInfo)
  ];
}
