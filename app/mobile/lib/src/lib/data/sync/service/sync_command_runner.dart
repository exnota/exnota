import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutator.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_runner.g.dart';

@riverpod
class SyncCommandRunner extends _$SyncCommandRunner {
  @override
  FutureOr<void> build() {
    // no op
  }

  void run() {
    final logger = ref.read(loggerProvider('SyncCommandRunner'));
    final db = ref.read(databaseProvider);
    final mutator = ref.read(syncCommandMutatorProvider.notifier);
    final commandRepo = SyncCommandRepo(db);
    commandRepo
        .fetchAllStream(status: SyncCommandStatus.waiting)
        .listen((commands) async {
      if (commands.isEmpty) {
        logger.debug("No commands found");
        return;
      }

      for (final command in commands) {
        logger.info("Executing command...", command);
        // TODO: Update this to be setRunning which updates the command but also
        // the entity sync status
        await mutator.setStatus(
            command.id.idOrThrow, SyncCommandStatus.running);
        SyncCommandError? error;
        try {
          error = await command.request(ref);
        } catch (e) {
          logger.error("Error executing command", nonPrivateData: {
            "command": command.runtimeType,
            "error": e,
          });
          await mutator.setStatus(
              command.id.idOrThrow, SyncCommandStatus.error);
          continue;
        }
        if (error != null) {
          logger.warn("Command failed", nonPrivateData: {
            "command": command.runtimeType,
            "error": error,
          });
          await mutator.setStatus(
              command.id.idOrThrow, SyncCommandStatus.error);
          continue;
        }
        logger.debug("Finished executing", command);
        await mutator.setComplete(command.id.idOrThrow);
        logger.debug("Command status updated");
      }
    });
  }
}
