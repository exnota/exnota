import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
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
    // TODO: Test that if this method throws an error, the calling
    // method transaction is also aborted

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

  Future<void> setStatus(int id, SyncCommandStatus status) async {
    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      final syncCommandRepo = SyncCommandRepo(db);
      await syncCommandRepo.setStatus(id, status);
    });
  }
}
