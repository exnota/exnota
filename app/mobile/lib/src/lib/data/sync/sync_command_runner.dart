import 'package:exnota/database.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/data/sync/sync_command_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_runner.g.dart';

@riverpod
class SyncCommandRunner extends _$SyncCommandRunner {
  @override
  FutureOr<void> build() {
    // no op
  }

  void run() {
    final logger = ref.read(loggerProvider);
    final db = ref.read(databaseProvider);
    final commandRepo = SyncCommandRepo(db);
    commandRepo
        .fetchAllStream(status: SyncCommandStatus.waiting)
        .listen((commands) async {
      logger.debug("Found commands", commands);
      if (commands.isEmpty) {
        return;
      }
      final command = commands[0];
      final result = await command.request();
      logger.debug("Command result", result);
      await commandRepo.setStatus(command.entityId, SyncCommandStatus.complete);
      logger.debug("Command status updated");
    });
  }
}
