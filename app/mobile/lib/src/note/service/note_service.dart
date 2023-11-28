import 'dart:math';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/note.dart';
import 'package:exnota/src/lib/data/sync/sync_command_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_service.g.dart';

enum NoteCreateError { authError, noPageError, network, other }

@riverpod
class NoteService extends _$NoteService {
  @override
  FutureOr<List<AudioNote>> build() {
    return [];
  }

  Future<void> insert(
      {required String filePath,
      required String transcription,
      String? url}) async {
    final previousState = await future;
    state = AsyncData([
      ...previousState,
      AudioNote(path: filePath, transcription: transcription, url: url)
    ]);
  }

  Future<void> create(String filePath) async {
    // Add command
    final db = ref.read(databaseProvider);
    final syncCommandRepo = SyncCommandRepo(db);
    int randomNum = Random().nextInt(100);
    await syncCommandRepo.createAudioNote(
        entityId: "entityId+$randomNum", filePath: filePath);
  }
}
