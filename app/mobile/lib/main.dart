// import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
// import 'package:exnota/src/context/audio/background_recorder.dart';
import 'package:exnota/src/context/device/device_info.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/lib/log/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

void main() async {
  final log = Logger(context: 'main');
  log.debug('Starting main');

  // Needed for the database, Firebase, and more. Don't know why :)
  WidgetsFlutterBinding.ensureInitialized();

  // One of this, or the session thing below, is needed currently because
  // otherwise recording doesn't seem to work. Strange.
  //
  // TODO: Figure out which one
  // final audioHandler = await AudioService.init(
  //   builder: () => MyAudioHandler(),
  //   config: const AudioServiceConfig(
  //       // androidNotificationChannelId: 'com.mycompany.myapp.channel.audio',
  //       // androidNotificationChannelName: 'Music playback',
  //       ),
  // );

  // Recording doesn't seem to work without this
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.record,
  ));

  // TODO: This is only required if the audio plugin we are using does not activate
  // the audio session
  //
  // Activate the audio session before playing audio.
  // if (await session.setActive(true)) {
  //   // Now play audio.
  //   // Continue below
  // } else {
  //   // The request was denied and the app should not play audio
  //   // TODO: Handle this better
  //   throw Exception('Failed to activate audio session');
  // }

  // Initialize device-context services
  final deviceInfo = await initDeviceInfoService();
  await initCrashlytics();
  final localFilePathGenerator = await initLocalFilePathGenerator();
  final db = initDatabase(files: localFilePathGenerator);

  // Overrides
  final overrides = getOverrides(
    db: db,
    deviceInfo: deviceInfo,
    localFilePathGenerator: localFilePathGenerator,
  );

  // TODO: Move sync command runner init to inside the user context
  // (possibly inside a workspace context)
  //
  // Sync command runner
  // await initSyncCommands(overrides: overrides);

  runApp(ProviderScope(overrides: overrides, child: const MyApp()));
}

List<Override> getOverrides(
    {required LocalPathGenerator localFilePathGenerator,
    required AppDatabase db,
    required DeviceInfo deviceInfo}) {
  return [
    localFilePathServiceProvider.overrideWithValue(localFilePathGenerator),
    databaseProvider.overrideWithValue(db),
    deviceInfoServiceProvider.overrideWithValue(deviceInfo)
  ];
}
