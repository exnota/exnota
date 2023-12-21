import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutation_service.dart';
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
    final mutationService =
        ref.read(syncCommandMutationServiceProvider.notifier);
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
        await mutationService.setStatus(
            command.id.idOrThrow, SyncCommandStatus.running);
        final error = await command.request(ref);
        if (error != null) {
          logger.warn("Command failed", nonPrivateData: {
            "command": command.runtimeType,
            "error": error,
          });
          // TODO: Handle error
          continue;
        }
        logger.debug("Finished executing", command);
        await mutationService.setComplete(command.id.idOrThrow);
        logger.debug("Command status updated");
      }
    });
  }
}
