import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/execute_transaction_sync_command.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/note/service/deprecated_note_mutation_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_mutation_service.g.dart';

@riverpod
class SyncCommandMutationService extends _$SyncCommandMutationService {
  @override
  FutureOr<void> build() {
    // no-op
  }

  Future<void> createAudioNote(
      {required String noteId,
      required String captureId,
      required String filePath}) async {
    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      final syncCommandRepo = SyncCommandRepo(db);

      final command = CreateAudioNoteSyncCommand.createPending(
          entityId: noteId,
          capture: (filePath: filePath, id: captureId),
          status: SyncCommandStatus.waiting);
      await syncCommandRepo.createCommand(command: command);
    });
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
    await transaction(() async {
      final syncCommandRepo = SyncCommandRepo(db);
      await syncCommandRepo.setStatus(id, status);
    });
  }

  Future<void> setComplete(int id) async {
    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      // Set command complete
      final syncCommandRepo = SyncCommandRepo(db);
      await syncCommandRepo.setStatus(id, SyncCommandStatus.complete);

      // Update sync status of entities
      final command = await syncCommandRepo.fetchById(id);
      switch (command) {
        case NoteSyncCommand():
          final captureId = command.captureId;
          if (captureId == null) {
            return;
          }
          final commandsForNote =
              await syncCommandRepo.fetchByEntityId(command.entityId);
          final hasMore = commandsForNote.any((c) =>
              c is NoteSyncCommand &&
              c.captureId == captureId &&
              c.status != SyncCommandStatus.complete);

          if (!hasMore) {
            await ref
                .read(deprecatedNoteMutationServiceProvider.notifier)
                .setCaptureSynced(captureId: captureId);
          }
          break;
        case ExecuteTransactionSyncCommand():
          // Do nothing. Sync status derived solely from command statuses.
          break;
        default:
          throw Exception("Unknown command type");
      }
    });
  }
}
