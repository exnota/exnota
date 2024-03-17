// singleton
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/audio/audio_recorder.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutator.dart';
import 'package:exnota/src/lib/file/service/local_file_mutator.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_block_recorder.freezed.dart';

@freezed
class AudioBlockRecorderState with _$AudioBlockRecorderState {
  const factory AudioBlockRecorderState({
    required bool recording,
    required DateTime? recordingStarted,
    required String? userId,
    required String? localFileId,
    required String? error,
  }) = _AudioBlockRecorderState;
}

class AudioBlockRecorder with ChangeNotifier {
  static final AudioBlockRecorder _instance = AudioBlockRecorder._internal();
  static final Logger _log = Logger(context: 'AudioBlockRecorder');

  late ProviderContainer _container;
  late AudioRecorder _audioBlockRecorder;

  AudioBlockRecorderState _state = const AudioBlockRecorderState(
    recording: false,
    recordingStarted: null,
    userId: null,
    localFileId: null,
    error: null,
  );

  factory AudioBlockRecorder({required ProviderContainer container}) {
    _instance._container = container;
    _instance._audioBlockRecorder = AudioRecorder(container: container);
    return _instance;
  }

  AudioBlockRecorder._internal();

  bool get recording => _state.recording;
  String? get error => _state.error;

  Future<void> record() async {
    _log.debug('record: Record');
    if (_state.recording) {
      _log.debug('record: Already recording');
      return;
    }

    final activeUserId = await _container.read(activeUserIdProvider.future);
    if (activeUserId == null) {
      _log.debug('record: No active user');
      _state = const AudioBlockRecorderState(
        recording: false,
        recordingStarted: null,
        userId: null,
        localFileId: null,
        error: 'No active user',
      );
      notifyListeners();
      return;
    }
    _log.debug('record: Active user found');

    final permissionResult =
        await _audioBlockRecorder.requestPermissionIfNeeded();
    if (permissionResult != AudioRecorderPermission.granted) {
      _log.debug('record: Permission denied');
      _state = const AudioBlockRecorderState(
        recording: false,
        recordingStarted: null,
        userId: null,
        localFileId: null,
        error: 'Recording permission denied',
      );
      notifyListeners();
      return;
    }

    final localFile = await _audioBlockRecorder.startRecording();
    if (localFile == null) {
      // No local file generated
      _log.debug('record: No local file generated');
      _state = const AudioBlockRecorderState(
        recording: false,
        recordingStarted: null,
        userId: null,
        localFileId: null,
        error: 'No local file generated',
      );
      notifyListeners();
      return;
    }

    _state = AudioBlockRecorderState(
      recording: true,
      recordingStarted: DateTime.now(),
      userId: activeUserId,
      localFileId: localFile.id,
      error: null,
    );
    notifyListeners();
  }

  Future<void> stop() async {
    _log.debug('stop: Stop');

    if (!_state.recording) {
      _log.debug('stop: Not recording');
      return;
    }

    _log.debug('stop: Stopping recording');
    await _audioBlockRecorder.stopRecording();

    // Persist command (which will also create a block)
    final commandMutator = SyncCommandMutator(container: _container);
    final command = CreateAudioBlockSyncCommand.createWaiting(
      userId: _state.userId!,
      data: CreateAudioBlockData(
        userId: _state.userId!,
        userCreated: _state.recordingStarted!,
        localFileId: _state.localFileId!,
      ),
    );
    await commandMutator.createCommand(command: command);

    // Persist block ID to local file now that it has been generated
    final localFileMutator = LocalFileMutator(_container);
    await localFileMutator.addEntityId(
      id: _state.localFileId!,
      entityId: command.entityId,
    );

    _state = const AudioBlockRecorderState(
      recording: false,
      recordingStarted: null,
      userId: null,
      localFileId: null,
      error: null,
    );
    notifyListeners();
  }
}
