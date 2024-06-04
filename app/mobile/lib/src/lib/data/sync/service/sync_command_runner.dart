import 'dart:async';

import 'package:exnota/src/context/workspace/block_importer.dart';
import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/set_block_destination_sync_command.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutator.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_runner.g.dart';
part 'sync_command_runner.freezed.dart';

/// How long to wait before considering a job to have been killed mid-processing
/// and should be retried (maybe the OS killed the app).
const commandTimeout = Duration(minutes: 5);

/// How long each command should wait for a response from the server before
/// timing out.
///
/// This should be less than [commandTimeout] so that jobs where the request
/// is taking too long can be distinguished from those that the OS killed.
final commandRequestTimeout = commandTimeout - const Duration(minutes: 1);

/// How frequently to check for timed-out jobs.
const timeoutCheckInterval = Duration(minutes: 1);

@Riverpod(keepAlive: true)
SyncCommandRunner syncCommandRunner(SyncCommandRunnerRef ref) {
  return SyncCommandRunner(ref.container);
}

@freezed
class RunnerState with _$RunnerState {
  static final Logger _log = Logger(context: 'RunnerState');

  // Needed to support methods on the class.
  const RunnerState._();

  factory RunnerState({
    required bool running,
    StreamSubscription? waitingSubscription,
    Timer? timedOutTimer,
  }) = _RunnerState;

  void cancelListeners() {
    _log.debug('Canceling listeners');
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

  /// Clears error status of jobs, then processes all jobs, oldest first, that:
  /// - have 'waiting' status
  /// - have 'running' status but have timed out
  ///
  /// If there is a 'running' job that has not timed out, it waits for it before
  /// processing the next job.
  void start() async {
    _log.debug('Start: Start');
    if (_state.running) {
      _log.debug('Start: Already running');
      return;
    }

    await _retryErroredJobs();

    await _processCommands();
  }

  Future<void> _retryErroredJobs() async {
    _log.debug('retryErroredJobs: Start');
    final mutator = SyncCommandMutator(container: _container);
    await mutator.retryAllErrored();
    _log.debug('retryErroredJobs: End');
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
      _log.debug('processCommands: Next command is ${nextCommand.runtimeType}'
          ' (id: ${nextCommand.id}) with status ${nextCommand.status} and'
          ' startedAt ${nextCommand.startedAt}');

      // If there's a running command that hasn't timed out, set a timer to wait
      // for it.
      if (nextCommand.status == SyncCommandStatus.running) {
        final now = _container.read(clockProvider).now();
        final timeout = nextCommand.startedAt!.add(commandTimeout);
        if (now.isBefore(timeout)) {
          _log.debug('processCommands: Setting timer for running command');
          _state = _state.copyWith(
            timedOutTimer: _timedOutTimer(),
          );
          break;
        }
      }

      // Process timed-out or waiting commands
      await _processNext(command: nextCommand);
    }

    _log.debug('processCommands: End');
  }

  /// Returns [Timer] that periodically for newly timed-out commands
  Timer _timedOutTimer() {
    final mutator = SyncCommandMutator(container: _container);
    return Timer.periodic(timeoutCheckInterval, (timer) async {
      _log.debug('processCommands: Checking for timed-out commands');
      final timedoutCommand =
          await mutator.fetchTimedOut(timeout: commandTimeout);
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
    _log.debug('processNext: Start (id: ${command.id})');

    // Set running. Will also reset startedAt if job timed out.
    final mutator = SyncCommandMutator(container: _container);
    await mutator.setRunning(id: command.id);

    try {
      // TODO: Based on type, get return from this and update local entities
      _log.debug('processNext: Starting syncUpdate');
      final updated = await command.syncUpdate(container: _container);
      _log.debug('processNext: syncUpdate complete');

      switch (command) {
        // Put all Block commands in same case. Ideally we'd group by the
        // generic on SyncCommand<T> but not sure it's possible to pattern match
        // that.
        case CreateAudioBlockSyncCommand():
        case SetBlockDestinationSyncCommand():
          _log.debug('processNext: Upserting block (id: ${updated.id})');
          await _container
              .read(blockImporterProvider.notifier)
              .import(block: updated);
          _log.debug('processNext: Upsert complete');
          break;
        default:
          throw Exception('Unknown command type');
      }
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
    _log.debug('processNext: End (id: ${command.id})');
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
