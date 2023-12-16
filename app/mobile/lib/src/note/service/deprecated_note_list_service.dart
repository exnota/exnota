import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/repo/drift/note_repo.dart';
import 'package:exnota/src/note/note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deprecated_note_list_service.g.dart';

@riverpod
Stream<List<Note>> deprecatedNoteListService(DeprecatedNoteListServiceRef ref) {
  final db = ref.read(databaseProvider);
  final noteRepo = NoteRepo(db);
  return noteRepo.list();
}
