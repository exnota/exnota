// widget called BackgroundRecorder that has state

import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

class MyAudioHandler extends BaseAudioHandler
    with
        QueueHandler, // mix in default queue callback implementations
        SeekHandler {
  // mix in default seek callback implementations
  final Logger _log = Logger(context: 'MyAudioHandler');

  // The most common callbacks:
  @override
  Future<void> play() async {
    // All 'play' requests from all origins route to here. Implement this
    // callback to start playing audio appropriate to your app. e.g. music.
    _log.debug('Detected "Play" request');
  }

  @override
  Future<void> pause() async {
    _log.debug('Detected "Pause" request');
  }

  @override
  Future<void> stop() async {
    _log.debug('Detected "Stop" request');
  }

  @override
  Future<void> seek(Duration position) async {
    _log.debug('Detected "Seek" request');
  }

  @override
  Future<void> skipToQueueItem(index) async {
    _log.debug('Detected "Skip to queue item" request');
  }
}

class BackgroundRecorder extends ConsumerStatefulWidget {
  const BackgroundRecorder({
    super.key,
  });

  @override
  ConsumerState<BackgroundRecorder> createState() => _BackgroundRecorderState();
}

class _BackgroundRecorderState extends ConsumerState<BackgroundRecorder> {
  final Logger _log = Logger(context: 'BackgroundRecorder');
  // late final BackgroundRecorderNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
    // _notifier = ref.read(backgroundRecorderNotifierProvider.notifier);
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    // _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');
    return const SizedBox.shrink();
  }
}
