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
    Stream? activeUserJobs,
  }) = _RunnerState;
}

class SyncCommandRunner {
  static final Logger _log = Logger(context: 'SyncCommandRunner');

  final ProviderContainer _container;
  late RunnerState _state = RunnerState(running: false, activeUserJobs: null);

  SyncCommandRunner(this._container);

  void start() async {
    _log.debug('Start: Start');
    if (_state.running) {
      _log.debug('Start: Already running');
      return;
    }

    // TODO: Need to clear activeUserJobs?
    _state = RunnerState(running: true, activeUserJobs: null);

    // TODO: Throw while loop around this instead of recursion??
    await _processNextCommand();
  }

  Future<void> _processNextCommand() async {
    _log.debug('Process next command: Start');

    final mutator = SyncCommandMutator(container: _container);
    final nextCommand =
        await mutator.fetchNextForActiveUser(runningTimeout: runningJobTimeout);

    if (nextCommand == null) {
      _log.debug('Process next command: No command found');
      // TODO: Any special handling?
      return;
    }
    _log.debug('Process next command: Found command', {
      'id': nextCommand.id,
      'entityId': nextCommand.entityId,
      'rootEntityId': nextCommand.rootEntityId,
      'status': nextCommand.status,
      'result': nextCommand.result,
      'createdAt': nextCommand.createdAt,
      'startedAt': nextCommand.startedAt,
    });

    // Set running. Will also reset startedAt if job timed out.
    await mutator.setRunning(id: nextCommand.id);

    try {
      // TODO: Based on type, get return from this and update local entities
      _log.debug('Process next command: Executing command', {
        'command': nextCommand.runtimeType,
      });
      await nextCommand.syncUpdate(container: _container);
      _log.debug('Process next command: Command executed', {
        'command': nextCommand.runtimeType,
      });
    } catch (e) {
      // TODO: Improve specific error type handling.
      _log.debug('Error executing command', {
        'command': nextCommand.runtimeType,
        'error': e,
      });
      await mutator.setErrored(
          id: nextCommand.id, error: SyncCommandError(e.toString()));
      _state = RunnerState(running: false, activeUserJobs: null);
      return;
    }

    await mutator.setComplete(id: nextCommand.id);
    _state = RunnerState(running: false, activeUserJobs: null);

    await _processNextCommand();

    // - catch and persist errors
    // - sends request/update local entities
    // TODO: vii: repeat on success OR error (if error, don't retry the same job (for now... can add later))

    // TODO: If returned job is running, it's because it's older than x minutes
    // and we need to restart it

    // TODO: When setting to running, set 'startedAt' to now
  }

  void stop() {
    _log.debug('Stop: Start');
    // TODO:
  }
}
