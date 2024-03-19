import 'dart:async';

import 'package:exnota/src/lib/data/sync/service/sync_command_mutator.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_runner.g.dart';
part 'sync_command_runner.freezed.dart';

/// How long to wait before considering a job to have been aborted and should
/// be retried (maybe the OS killed the app).
const runningJobTimeout = Duration(minutes: 5);

@Riverpod(keepAlive: true)
SyncCommandRunner syncCommandRunner(SyncCommandRunnerRef ref) {
  return SyncCommandRunner(ref.container);
}

@freezed
class RunnerState with _$RunnerState {
  factory RunnerState({
    required bool running,
    StreamSubscription? jobsSubscription,
  }) = _RunnerState;
}

class SyncCommandRunner {
  static final Logger _log = Logger(context: 'SyncCommandRunner');

  final ProviderContainer _container;
  late RunnerState _state = RunnerState(running: false, jobsSubscription: null);

  SyncCommandRunner(this._container);

  void start() async {
    _log.debug('Start: Start');
    if (_state.running) {
      _log.debug('Start: Already running');
      return;
    }

    await _processWaitingCommands();
  }

  Future<void> _processWaitingCommands() async {
    _log.debug('Process waiting commands: Start');
    _state = RunnerState(running: true, jobsSubscription: null);

    final mutator = SyncCommandMutator(container: _container);

    while (true) {
      final nextCommand = await mutator.fetchNextForActiveUser(
          runningTimeout: runningJobTimeout);

      if (nextCommand == null) {
        _log.debug('Process waiting commands: No command found');
        break;
      }

      await _processNextCommand(command: nextCommand);
    }

    final stream =
        mutator.watchNextForActiveUser(runningTimeout: runningJobTimeout);

    _log.debug('Process waiting commands: Watching for new commands');
    final subscription = stream.listen((event) {
      if (event.isEmpty) {
        return;
      }
      _log.debug('Process waiting commands: New command found');
      _state.jobsSubscription?.cancel();

      // Ignore the commands found in this listener and start processing again,
      // which will fetch the new commands.
      _processWaitingCommands();
    });
    _state = RunnerState(running: true, jobsSubscription: subscription);
  }

  Future<void> _processNextCommand({required SyncCommand command}) async {
    _log.debug('Process next command: Processing command:', {
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
      _log.debug('Process next command: Executing command', {
        'command': command.runtimeType,
      });
      await command.syncUpdate(container: _container);
      _log.debug('Process next command: Command executed', {
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
    _state.jobsSubscription?.cancel();
    _state = RunnerState(running: false, jobsSubscription: null);
  }
}
