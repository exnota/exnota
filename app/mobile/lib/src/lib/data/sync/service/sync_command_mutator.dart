import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncCommandMutator {
  final ProviderContainer _container;

  SyncCommandMutator({required ProviderContainer container})
      : _container = container;

  Future<void> createCommand({required SyncCommand command}) async {
    final db = _container.read(databaseProvider);
    final transaction = _container.read(transactionProvider);
    await transaction(() async {
      // Persist command
      final syncCommandRepo = SyncCommandRepo(db);
      await syncCommandRepo.createCommand(command: command);

      // Persist entity
      switch (command) {
        // Put all Block commands in same case. Ideally we'd group by the
        // generic on SyncCommand<T> but not sure it's possible to pattern match
        // that.
        case CreateAudioBlockSyncCommand():
          final blockId = command.entityId;
          final blockRepo = BlockRepo(db);
          final current = await blockRepo.fetchById(blockId);

          // Update or create the entity using the command's localUpdate method.
          final updated = await command.localUpdate(current: current);
          await blockRepo.upsert(updated);
          break;
        default:
          throw Exception('Unknown command type');
      }
    });
  }

  // Future<void> setStatus(int id, SyncCommandStatus status) async {
  //   final db = _container.read(databaseProvider);
  //   final transaction = _container.read(transactionProvider);
  //   final now = _container.read(clockProvider).now();
  //   await transaction(() async {
  //     final syncCommandRepo = SyncCommandRepo(db);
  //     await syncCommandRepo.setStatus(id: id, status: status, updatedAt: now);
  //   });
  // }

  // Future<void> setComplete(int id) async {
  //   final db = _container.read(databaseProvider);
  //   final transaction = _container.read(transactionProvider);
  //   final now = _container.read(clockProvider).now();
  //   await transaction(() async {
  //     // Set command complete
  //     final syncCommandRepo = SyncCommandRepo(db);
  //     await syncCommandRepo.setStatus(
  //         id: id, status: SyncCommandStatus.complete, updatedAt: now);

  //     // Update sync status of entities
  //     final command = await syncCommandRepo.fetchById(id);
  //     switch (command) {
  //       case ExecuteTransactionSyncCommand():
  //         // Do nothing. Sync status derived solely from command statuses.
  //         break;
  //       default:
  //         throw Exception('Unknown command type');
  //     }
  //   });
  // }

  // Future<void> retryForRootEntity({required String id}) async {
  //   final transaction = _container.read(transactionProvider);
  //   final repo = _container.read(syncCommandRepoProvider);
  //   final now = _container.read(clockProvider).now();
  //   await transaction(() async {
  //     final all = await repo.fetchByRootEntityId(id);
  //     if (all.isEmpty) {
  //       ref
  //           .read(loggerProvider('SyncCommandMutator'))
  //           .warn('No commands found for root entity $id');
  //       return;
  //     }
  //     final errored = all.where((c) => c.status == SyncCommandStatus.error);
  //     if (errored.isEmpty) {
  //       ref
  //           .read(loggerProvider('SyncCommandMutator'))
  //           .warn('No errored commands found for root entity $id');
  //       return;
  //     }
  //     for (final command in errored) {
  //       await repo.setStatus(
  //           id: command.id.idOrThrow,
  //           status: SyncCommandStatus.waiting,
  //           updatedAt: now);
  //     }
  //   });
  // }

  // Future<void> retryAllRunning() async {
  //   final transaction = _container.read(transactionProvider);
  //   final repo = _container.read(syncCommandRepoProvider);
  //   final now = _container.read(clockProvider).now();
  //   final logger = _container.read(loggerProvider('SyncCommandMutator'));
  //   await transaction(() async {
  //     final all = await repo.fetchAll(status: SyncCommandStatus.running);
  //     if (all.isEmpty) {
  //       return;
  //     }
  //     for (final command in all) {
  //       logger.info('Retrying command ${command.id}', {
  //         'previousUpdatedAt': command.updatedAt.toIso8601String(),
  //       });
  //       await repo.setStatus(
  //           id: command.id.idOrThrow,
  //           status: SyncCommandStatus.waiting,
  //           updatedAt: now);
  //     }
  //   });
  // }
}
