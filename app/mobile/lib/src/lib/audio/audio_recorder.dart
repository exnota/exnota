import 'package:exnota/src/context/device/local_file_path_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

enum AudioRecorderPermission {
  granted,
  denied,
  unknown,
}

class AudioRecorder with ChangeNotifier {
  static final Logger _log = Logger(context: 'AudioRecorder');

  static final AudioRecorder _instance = AudioRecorder._internal();
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  late ProviderContainer _container;
  PermissionStatus? _permissionStatus;

  factory AudioRecorder({required ProviderContainer container}) {
    _instance._container = container;
    return _instance;
  }

  AudioRecorder._internal();

  @override
  void dispose() {
    _log.debug('dispose: Disposing');
    _recorder.stopRecorder();
    _recorder.closeRecorder();
    super.dispose();
  }

  bool isRecording() {
    _log.debug('isRecording: ${_recorder.isRecording}');
    return _recorder.isRecording;
  }

  /// Return the current known permission status. 'unknown' if it hasn't been
  /// checked yet.
  ///
  /// It's updated when calling [requestPermissionIfNeeded].
  AudioRecorderPermission getPermissionStatus() {
    _log.debug('getPermissionStatus: $_permissionStatus');
    if (_permissionStatus != null) {
      if (_permissionStatus == PermissionStatus.granted) {
        return AudioRecorderPermission.granted;
      } else {
        return AudioRecorderPermission.denied;
      }
    }

    return AudioRecorderPermission.unknown;
  }

  Future<void> startRecording() async {
    _log.debug('startRecording: Start');
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final path = await _container
        .read(localFilePathServiceProvider)
        .generateAudioBlockFilePath(
            localFileId: 'test-$random', extension: 'wav');

    _log.debug('startRecording: Opening recorder');
    await _recorder.openRecorder();

    _log.debug('startRecording: Starting recorder with path: $path');
    // Codec platform support: https://flutter-sound.canardoux.xyz/guides_codec.html
    // TODO: wav is kinda big, we should probably change to something else.
    await _recorder.startRecorder(toFile: path, codec: Codec.pcm16WAV);
    _log.debug('startRecording: Started recording.');

    // Notify isRecording has changed
    notifyListeners();
  }

  Future<void> stopRecording() async {
    _log.debug('stopRecording: Stopping recorder');
    await _recorder.stopRecorder();

    _log.debug('stopRecording: Closing recorder');
    await _recorder.closeRecorder();
    _log.debug('stopRecording: Stopped recording.');

    // Notify isRecording has changed
    notifyListeners();
  }

  Future<AudioRecorderPermission> requestPermissionIfNeeded() async {
    _log.debug('requestPermissionIfNeeded: Requesting permission');
    _permissionStatus = await Permission.microphone.request();
    _log.debug(
        'requestPermissionIfNeeded: Permission status: $_permissionStatus');
    return getPermissionStatus();
  }
}
