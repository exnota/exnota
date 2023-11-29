import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/drift/capture_table.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
import 'package:exnota/src/note/data/id_generator.dart';
import 'package:exnota/src/note/note.dart';
import 'package:drift/extensions/json1.dart';

class NoteRepo {
  final AppDatabase db;

  NoteRepo(this.db);

  Future<VoiceNote> createVoiceNote({required String filePath}) async {
    final captureId = generateId();
    CaptureTableCompanion captureCompanion = CaptureTableCompanion.insert(
      id: captureId,
      type: CaptureTableType.audio,
    );

    final id = generateId();
    NoteTableCompanion noteCompanion = NoteTableCompanion.insert(
        id: id,
        type: NoteTableType.voice,
        title: const Value.absent(),
        captures: NoteTableCaptures(captures: [captureCompanion.id.value]),
        localData: LocalDataAll(
            status: LocalStatusRepo.capturing, filePath: filePath));

    final note = await db.transaction(() async {
      await db.into(db.captureTable).insertReturning(captureCompanion);
      await db.into(db.noteTable).insertReturning(noteCompanion);
      return await getNoteById(id);
    });
    if (note is VoiceNote) {
      return note;
    } else {
      throw Exception("Note is not a VoiceNote");
    }
  }

  Future<Note> getNoteById(String id) async {
    final referencedCaptures =
        db.noteTable.captures.jsonEach(db, r'$.captures');

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

      return NoteRepoMapper.fromData(noteData, capturesData);
    }).first;
  }
}

class NoteRepoMapper {
  static Note fromData(NoteTableData data, List<CaptureTableData> captures) {
    switch (data.type) {
      case NoteTableType.voice:
        return _voiceNoteFromData(data, captures);
      default:
        throw Exception("Unknown note type: ${data.type}");
    }
  }

  static VoiceNote _voiceNoteFromData(
      NoteTableData data, List<CaptureTableData> captures) {
    final localData = VoiceNoteLocalData(
      filePath: data.localData.filePath,
      status: _localStatusFromData(data.localData.status),
    );

    return VoiceNote(
      id: data.id,
      title: data.title,
      captures: captures.map((capture) {
        switch (capture.type) {
          case CaptureTableType.audio:
            return AudioFileCapture(
              id: capture.id,
            );
          default:
            throw Exception("Unknown capture type: ${capture.type}");
        }
      }).toList(),
      localData: localData,
    );
  }

  static LocalStatus _localStatusFromData(LocalStatusRepo status) {
    switch (status) {
      case LocalStatusRepo.capturing:
        return LocalStatus.capturing;
      case LocalStatusRepo.captured:
        return LocalStatus.captured;
      case LocalStatusRepo.synced:
        return LocalStatus.synced;
    }
  }
}
