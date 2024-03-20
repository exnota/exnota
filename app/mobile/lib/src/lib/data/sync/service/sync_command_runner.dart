import 'dart:async';

import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutator.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_runner.g.dart';
part 'sync_command_runner.freezed.dart';

/// How long to wait before considering a job to have been killed mid-processing
/// and should be retried (maybe the OS killed the app).
const timeoutDuration = Duration(minutes: 5);

/// How frequently to check for timed-out jobs.
const timeoutCheckInterval = Duration(minutes: 1);

@Riverpod(keepAlive: true)
SyncCommandRunner syncCommandRunner(SyncCommandRunnerRef ref) {
  return SyncCommandRunner(ref.container);
}

@freezed
class RunnerState with _$RunnerState {
  // Needed to support methods on the class.
  const RunnerState._();

  factory RunnerState({
    required bool running,
    StreamSubscription? waitingSubscription,
    Timer? timedOutTimer,
  }) = _RunnerState;

  void cancelListeners() {
    waitingSubscription?.cancel();
    timedOutTimer?.cancel();
  }
}

class SyncCommandRunner {
  static final Logger _log = Logger(context: 'SyncCommandRunner');

  final ProviderContainer _container;
  late RunnerState _state = RunnerState(
    running: false,
    waitingSubscription: null,
  );

  SyncCommandRunner(this._container);

  void start() async {
    _log.debug('Start: Start');
    if (_state.running) {
      _log.debug('Start: Already running');
      return;
    }

    await _processCommands();
  }

  Future<void> _processCommands() async {
    _log.debug('processCommands: Start');

    // Cleanup state
    _state.cancelListeners();
    _state = RunnerState(
      running: true,
      waitingSubscription: null,
      timedOutTimer: null,
    );

    // Loop through all running and waiting commands
    final mutator = SyncCommandMutator(container: _container);
    while (_state.running) {
      final nextCommand = await mutator.fetchRunningOrWaiting();

      if (nextCommand == null) {
        _log.debug('processCommands: No command found');
        _state = _state.copyWith(
          waitingSubscription: _waitingSubscription(),
        );
        break;
      }

      // If there's a running command that hasn't timed out, set a timer to wait
      // for it.
      if (nextCommand.status == SyncCommandStatus.running) {
        final now = _container.read(clockProvider).now();
        final timeout = nextCommand.startedAt!.add(timeoutDuration);
        if (now.isBefore(timeout)) {
          _state = _state.copyWith(
            timedOutTimer: _timedOutTimer(),
          );
          break;
        }
      }

      // Process timed-out or waiting commands
      await _processNext(command: nextCommand);
    }
  }

  /// Returns [Timer] that periodically for newly timed-out commands
  Timer _timedOutTimer() {
    final mutator = SyncCommandMutator(container: _container);
    return Timer.periodic(timeoutCheckInterval, (timer) async {
      _log.debug('processCommands: Checking for timed-out commands');
      final timedoutCommand =
          await mutator.fetchTimedOut(timeout: timeoutDuration);
      if (timedoutCommand != null) {
        _log.debug('processCommands: Timed-out command found');

        // Ignore the command passed as an argument here and instead recursively
        // call this function to start the process again.
        await _processCommands();
      }
    });
  }

  StreamSubscription<List<SyncCommand<dynamic>>> _waitingSubscription() {
    _log.debug('processCommands: Watching for new commands');
    final mutator = SyncCommandMutator(container: _container);
    final stream = mutator.watchWaiting();
    return stream.listen((commands) {
      if (commands.isEmpty) {
        return;
      }
      _log.debug('processCommands: New command(s) found');
      _state.cancelListeners();

      // Ignore the commands passed as an argument here and instead recursively
      // call this function to start the process again.
      _processCommands();
    });
  }

  Future<void> _processNext({required SyncCommand command}) async {
    _log.debug('processNext: Processing command:', {
      'id': command.id,
      'entityId': command.entityId,
      'rootEntityId': command.rootEntityId,
      'status': command.status,
      'result': command.result,
      'createdAt': command.createdAt,
      'startedAt': command.startedAt,
    });

    // Set running. Will also reset startedAt if job timed out.
    final mutator = SyncCommandMutator(container: _container);
    await mutator.setRunning(id: command.id);

    try {
      // TODO: Based on type, get return from this and update local entities
      _log.debug('processNext: Executing command', {
        'command': command.runtimeType,
      });
      final updated = await command.syncUpdate(container: _container);

      switch (command) {
        // Put all Block commands in same case. Ideally we'd group by the
        // generic on SyncCommand<T> but not sure it's possible to pattern match
        // that.
        case CreateAudioBlockSyncCommand():
          final blockRepo = _container.read(blockRepoProvider);
          await blockRepo.upsert(updated);
          break;
        default:
          throw Exception('Unhandled command type');
      }

      _log.debug('processNext: Command executed', {
        'command': command.runtimeType,
      });
    } catch (e) {
      // TODO: Improve specific error type handling.
      _log.debug('Error executing command', {
        'command': command.runtimeType,
        'error': e,
      });
      await mutator.setErrored(
          id: command.id, error: SyncCommandError(e.toString()));
      return;
    }

    await mutator.setComplete(id: command.id);
  }

  void stop() {
    _log.debug('Stop: Start');
    _state.cancelListeners();
    _state = RunnerState(
      running: false,
      waitingSubscription: null,
      timedOutTimer: null,
    );
  }
}
