import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/data/drift/note_repo.dart';
import 'package:exnota/src/note/note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_list_service.g.dart';

@riverpod
Stream<List<Note>> noteListService(NoteListServiceRef ref) {
  final db = ref.read(databaseProvider);
  final noteRepo = NoteRepo(db);
  return noteRepo.list();
}
