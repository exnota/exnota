import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/service/local_file_mutator.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:permission_handler/permission_handler.dart';

part 'audio_recorder.freezed.dart';

enum AudioRecorderPermission {
  granted,
  denied,
  unknown,
}

@freezed
class RecordingState with _$RecordingState {
  const factory RecordingState({LocalFile? localeFile}) = _RecordingState;
}

/// Singleton class to handle audio recording.
///
/// Persists LocalFile to the database with information about the recording file.
///
/// Notifies when [recording] changes.
class AudioRecorder with ChangeNotifier {
  static final Logger _log = Logger(context: 'AudioRecorder');

  static final AudioRecorder _instance = AudioRecorder._internal();
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  late ProviderContainer _container;
  PermissionStatus? _permissionStatus;
  RecordingState? _recordingState;

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

  bool get recording => _recordingState != null;

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

    if (_recordingState != null) {
      _log.debug('startRecording: Already recording');
      return;
    }
    _recordingState = const RecordingState();
    // Notify [recording] has changed
    notifyListeners();

    // Create local file
    _log.debug('startRecording: Creating local file');
    final mutator = LocalFileMutator(_container);
    final localFile = await mutator.createForAudioBlock(
      extension: 'wav',
      status: Status.recording,
    );
    _recordingState = RecordingState(localeFile: localFile);

    // Start recording
    _log.debug('startRecording: Opening recorder');
    await _recorder.openRecorder();
    _log.debug('startRecording: Starting recorder with path: $localFile.path');
    // Codec platform support: https://flutter-sound.canardoux.xyz/guides_codec.html
    // TODO: wav is kinda big, we should probably change to something else.
    await _recorder.startRecorder(
        toFile: localFile.path, codec: Codec.pcm16WAV);
    _log.debug('startRecording: Started recording.');
  }

  Future<void> stopRecording() async {
    _log.debug('stopRecording: Stop');
    if (_recordingState == null) {
      _log.debug('stopRecording: Not recording');
      return;
    }

    // Stop recording
    _log.debug('stopRecording: Stopping recorder');
    await _recorder.stopRecorder();
    _log.debug('stopRecording: Closing recorder');
    await _recorder.closeRecorder();
    _log.debug('stopRecording: Stopped recording.');

    // Update local file status
    _log.debug('stopRecording: Updating local file status');
    final mutator = LocalFileMutator(_container);
    await mutator.updateStatus(
      id: _recordingState!.localeFile!.id,
      status: Status.saved,
    );

    _recordingState = null;
    // Notify [recording] has changed
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
