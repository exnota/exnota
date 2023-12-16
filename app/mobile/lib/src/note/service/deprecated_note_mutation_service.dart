// ignore_for_file: dead_code

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutation_service.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/repo/drift/note_repo.dart';
import 'package:exnota/src/note/note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deprecated_note_mutation_service.g.dart';

enum NoteCreateError { authError, noPageError, network, other }

@riverpod
class DeprecatedNoteMutationService extends _$DeprecatedNoteMutationService {
  @override
  FutureOr<void> build() {
    // no-op
  }

  Future<VoiceNote> createCapturingAudioNote(
      {required String extension}) async {
    VoiceNote note = VoiceNote.createCapturing();

    // Set filepath
    final captureId = note.captures.first.id;
    final filePath = ref
        .read(localFilePathServiceProvider)
        .deprecatedGetVoiceNoteFilePath(
            captureId: captureId, extension: extension);
    note = note.withFilePath(captureId: captureId, filePath: filePath);

    final db = ref.read(databaseProvider);
    final noteRepo = NoteRepo(db);
    await noteRepo.createVoiceNote(note: note);
    return note;
  }

  Future<void> setAudioFileCaptured({required AudioFileCapture capture}) async {
    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      // Get note from DB
      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepo(db);
      final existingNote = await noteRepo.getNoteByCaptureId(capture.id);
      if (existingNote is! VoiceNote) {
        ref
            .read(loggerProvider('NoteMutationService.setAudioFileCaptured'))
            .error("Note is not a VoiceNote",
                nonPrivateData: existingNote.toNonPrivateData());
        // TODO: Handle error
        return;
      }

      // Set capture as captured
      final updatedNote = existingNote.withCaptured(captureId: capture.id);
      await noteRepo.updateVoiceNote(updatedNote: updatedNote);

      final filePath = capture.localData.filePath;
      if (filePath == null) {
        throw Exception("Cannot create command without filePath");
      }
      await ref
          .read(syncCommandMutationServiceProvider.notifier)
          .createAudioNote(
              noteId: updatedNote.id,
              captureId: capture.id,
              filePath: filePath);
    });
  }

  Future<void> setAudioFileData(
      {required String captureId,
      required String transcription,
      String? integratedUrl}) async {
    final transaction = ref.read(transactionProvider);

    await transaction(() async {
      // Get note from DB
      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepo(db);
      final existingNote = await noteRepo.getNoteByCaptureId(captureId);
      if (existingNote is! VoiceNote) {
        ref
            .read(loggerProvider('NoteMutationService.setAudioFileSynced'))
            .error("Note is not a VoiceNote",
                nonPrivateData: existingNote.toNonPrivateData());
        // TODO: Handle error
        return;
      }

      var updatedNote = existingNote.withTranscription(
          captureId: captureId, transcription: transcription);
      updatedNote = updatedNote.withIntegratedUrl(url: integratedUrl);

      await noteRepo.updateVoiceNote(updatedNote: updatedNote);
    });
  }

  Future<void> setCaptureSynced({required String captureId}) async {
    final transaction = ref.read(transactionProvider);

    await transaction(() async {
      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepo(db);
      final existingNote = await noteRepo.getNoteByCaptureId(captureId);
      final updatedNote = existingNote.withSynced(captureId: captureId);
      await noteRepo.updateVoiceNote(updatedNote: updatedNote);
    });
  }
}
