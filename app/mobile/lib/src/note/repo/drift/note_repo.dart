import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift/extensions/json1.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/repo/drift/deprecated_mapper.dart';
import 'package:exnota/src/note/note.dart';

class NoteRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  NoteRepo(this.db);

  Stream<List<Note>> list() {
    final query = db.select(db.noteTable);
    query.orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.asyncMap<Note>((noteData) async {
      return await getNoteByIdOrThrow(noteData.id);
    }).watch();
  }

  Future<void> createVoiceNote({required Note note}) async {
    List<CaptureTableData> captureDatas = note.captures
        .map((c) => DeprecatedNoteRepoMapper.captureToData(c))
        .toList();
    NoteTableData noteData = DeprecatedNoteRepoMapper.noteToData(note);

    await db.transaction(() async {
      for (final captureData in captureDatas) {
        await db.into(db.captureTable).insert(captureData);
      }
      await db.into(db.noteTable).insert(noteData);
    });
  }

  Future<void> updateVoiceNote({
    required Note updatedNote,
  }) async {
    // Log significant changes to captures that are currently not expected.
    final existingNote = await getNoteById(updatedNote.id);
    if (existingNote != null) {
      // Log if note type has changed
      if (existingNote.runtimeType != updatedNote.runtimeType) {
        logger.warn("Note type changed for note ${updatedNote.id}",
            nonPrivateData: {
              "existingNote": existingNote.toNonPrivateData(),
              "updatedNote": updatedNote.toNonPrivateData(),
            });
      }

      final newCaptures = updatedNote.captures //
          .where((updatedCapture) => existingNote.captures.none(
              (existingCapture) => existingCapture.id == updatedCapture.id));
      if (newCaptures.isNotEmpty) {
        logger.warn("New captures for note ${updatedNote.id}",
            nonPrivateData:
                newCaptures.map((c) => c.toNonPrivateData()).toList());
      }

      final removedCaptures = existingNote.captures //
          .where((existingCapture) => updatedNote.captures.none(
              (updatedCapture) => updatedCapture.id == existingCapture.id));
      if (removedCaptures.isNotEmpty) {
        logger.warn("Removed captures for note ${updatedNote.id}",
            nonPrivateData:
                removedCaptures.map((c) => c.toNonPrivateData()).toList());
      }

      final changedTypeCaptures = existingNote.captures //
          .where((existingCapture) => updatedNote.captures.any(
              (updatedCapture) =>
                  updatedCapture.id == existingCapture.id &&
                  updatedCapture.runtimeType != existingCapture.runtimeType));
      if (changedTypeCaptures.isNotEmpty) {
        logger.warn("Changed type for captures for note ${updatedNote.id}",
            nonPrivateData:
                changedTypeCaptures.map((c) => c.toNonPrivateData()).toList());
      }
    }

    // Upsert captures, leave dangling in database as they are not expected
    // and we want to avoid data loss.
    List<CaptureTableData> captureDatas = updatedNote.captures
        .map((c) => DeprecatedNoteRepoMapper.captureToData(c))
        .toList();
    NoteTableData noteData = DeprecatedNoteRepoMapper.noteToData(updatedNote);

    await db.transaction(() async {
      for (final captureData in captureDatas) {
        await db.into(db.captureTable).insertOnConflictUpdate(captureData);
      }
      await db.into(db.noteTable).insertOnConflictUpdate(noteData);
    });
  }

  Future<Note?> getNoteById(String id) async {
    final referencedCaptures = db.noteTable.captures.jsonEach(db);

    final noteWithCapturesQuery = db.select(db.noteTable).join(
      [
        // Join every referenced item from the json array
        innerJoin(referencedCaptures, const Constant(true), useColumns: false),
        // And use that to join the items
        innerJoin(
          db.captureTable,
          db.captureTable.id.equalsExp(referencedCaptures.value.cast()),
        ),
      ],
    )..where(db.noteTable.id.equals(id));

    // Could only get this working using .watch() instead of .get(). Used this
    // as a reference https://drift.simonbinder.eu/docs/examples/relationships/#with-json-functions
    return await noteWithCapturesQuery.watch().map((rows) {
      late NoteTableData noteData;
      final capturesData = <CaptureTableData>[];

      for (final row in rows) {
        noteData = row.readTable(db.noteTable);
        capturesData.add(row.readTable(db.captureTable));
      }

      return DeprecatedNoteRepoMapper.fromData(noteData, capturesData);
    }).first;
  }

  Future<Note> getNoteByIdOrThrow(String id) async {
    final note = await getNoteById(id);
    if (note == null) {
      throw Exception("Note $id not found");
    }
    return note;
  }

  Future<Note> getNoteByCaptureId(String captureId) async {
    final noteData = await (db.select(db.noteTable)
          ..where((tbl) {
            return tbl.captures.contains(captureId);
          }))
        .getSingle();

    return getNoteByIdOrThrow(noteData.id);
  }
}
