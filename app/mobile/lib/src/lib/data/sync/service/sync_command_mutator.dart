import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/execute_transaction_sync_command.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_mutator.g.dart';

@riverpod
class SyncCommandMutator extends _$SyncCommandMutator {
  @override
  FutureOr<void> build() {
    // no-op
  }

  Future<void> createCommand({required SyncCommand command}) async {
    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      final syncCommandRepo = SyncCommandRepo(db);
      await syncCommandRepo.createCommand(command: command);
    });
  }

  Future<void> setStatus(int id, SyncCommandStatus status) async {
    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    final now = ref.read(clockProvider).now();
    await transaction(() async {
      final syncCommandRepo = SyncCommandRepo(db);
      await syncCommandRepo.setStatus(id: id, status: status, updatedAt: now);
    });
  }

  Future<void> setComplete(int id) async {
    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    final now = ref.read(clockProvider).now();
    await transaction(() async {
      // Set command complete
      final syncCommandRepo = SyncCommandRepo(db);
      await syncCommandRepo.setStatus(
          id: id, status: SyncCommandStatus.complete, updatedAt: now);

      // Update sync status of entities
      final command = await syncCommandRepo.fetchById(id);
      switch (command) {
        case ExecuteTransactionSyncCommand():
          // Do nothing. Sync status derived solely from command statuses.
          break;
        default:
          throw Exception("Unknown command type");
      }
    });
  }

  Future<void> retryForRootEntity({required String id}) async {
    final transaction = ref.read(transactionProvider);
    final repo = ref.read(syncCommandRepoProvider);
    final now = ref.read(clockProvider).now();
    await transaction(() async {
      final all = await repo.fetchByRootEntityId(id);
      if (all.isEmpty) {
        ref
            .read(loggerProvider('SyncCommandMutator'))
            .warn('No commands found for root entity $id');
        return;
      }
      final errored = all.where((c) => c.status == SyncCommandStatus.error);
      if (errored.isEmpty) {
        ref
            .read(loggerProvider('SyncCommandMutator'))
            .warn('No errored commands found for root entity $id');
        return;
      }
      for (final command in errored) {
        await repo.setStatus(
            id: command.id.idOrThrow,
            status: SyncCommandStatus.waiting,
            updatedAt: now);
      }
    });
  }
}
