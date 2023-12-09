// ignore_for_file: dead_code

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/drift/note_repo.dart';
import 'package:exnota/src/note/note.dart';
import 'package:exnota/src/lib/data/sync/sync_command_repo.dart';
import 'package:exnota/src/note/data/file/local_file_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_mutation_service.g.dart';

enum NoteCreateError { authError, noPageError, network, other }

@riverpod
class NoteMutationService extends _$NoteMutationService {
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
        .read(localFileServiceProvider)
        .getVoiceNoteFilePath(captureId: captureId, extension: extension);
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

      // TODO: Move to sync service?
      // Create sync command
      final syncCommandRepo = SyncCommandRepo(db);
      final filePath = capture.localData.filePath;
      if (filePath == null) {
        throw Exception(
            "Cannot create audio file captured command without filePath");
      }
      final command = CreateAudioNoteSyncCommand.createPending(
          entityId: updatedNote.id,
          capture: (filePath: filePath, id: capture.id),
          status: SyncCommandStatus.waiting);
      await syncCommandRepo.createCommand(command: command);
    });
  }

  Future<void> setAudioFileSynced(
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

      var updatedNote = existingNote.withSynced(captureId: captureId);
      updatedNote = updatedNote.withTranscription(
          captureId: captureId, transcription: transcription);
      updatedNote = updatedNote.withIntegratedUrl(url: integratedUrl);

      await noteRepo.updateVoiceNote(updatedNote: updatedNote);
    });
  }
}
