// ignore_for_file: dead_code

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/data/drift/note_repo.dart';
import 'package:exnota/src/note/note.dart';
import 'package:exnota/src/lib/data/sync/sync_command_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_mutation_service.g.dart';

enum NoteCreateError { authError, noPageError, network, other }

@riverpod
class NoteMutationService extends _$NoteMutationService {
  @override
  FutureOr<void> build() {
    // no-op
  }

  Future<VoiceNote> createCapturingAudioNote({required String filePath}) async {
    final note = VoiceNote.createCapturing(filePath: filePath);
    final db = ref.read(databaseProvider);
    final noteRepo = NoteRepo(db);
    await noteRepo.createVoiceNote(note: note);
    return note;
  }

  Future<void> setNoteCaptured({required VoiceNote note}) async {
    note = note.copyAsCaptured();

    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepo(db);
      await noteRepo.updateVoiceNote(updatedNote: note);

      final syncCommandRepo = SyncCommandRepo(db);
      final filePath = note.localData.filePath;
      if (filePath == null) {
        throw Exception("Cannot create command without filePath");
      }
      await syncCommandRepo.createAudioNote(
          entityId: note.id, filePath: filePath);
    });
  }

  Future<void> setNoteSynced(
      {required String id,
      required String title,
      String? integratedUrl}) async {
    final transaction = ref.read(transactionProvider);

    await transaction(() async {
      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepo(db);
      Note? note = await noteRepo.getNoteById(id);
      if (note == null) {
        ref.read(loggerProvider).error("Note not found", nonPrivateData: {
          "id": id,
          "integrationUrl": integratedUrl,
        });
        return;
      }
      if (note is! VoiceNote) {
        ref.read(loggerProvider).error("Note is not a VoiceNote",
            nonPrivateData: note.toNonPrivateData());
        return;
      }
      note = note.copyAsSynced();
      note = note.copyWithTitle(title: title);
      note = note.copyWithIntegratedUrl(url: integratedUrl);

      await noteRepo.updateVoiceNote(updatedNote: note);
    });
  }
}
