import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift/extensions/json1.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/lib/optional.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/drift/capture_table.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
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
    List<CaptureTableData> captureDatas = [];
    for (final capture in note.captures) {
      switch (capture) {
        case AudioFileCapture():
          captureDatas.add(CaptureTableData(
            id: capture.id,
            type: CaptureTableType.audio,
            createdAt: capture.createdAt,
            localData: CaptureLocalDataAll(
              filePath: capture.localData.filePath,
              status: NoteRepoMapper.captureLocalStatusToData(
                  capture.localData.status),
            ),
            typeData: CaptureTypeDataAll(
              transcription: capture.transcription,
            ),
          ));
          break;
        case UnknownCapture():
          captureDatas.add(CaptureTableData(
              id: capture.id,
              type: CaptureTableType.unknown,
              createdAt: capture.createdAt,
              localData: CaptureLocalDataAll(
                status: NoteRepoMapper.captureLocalStatusToData(
                    capture.localData.status),
              ),
              typeData: CaptureTypeDataAll()));
          break;
      }
    }

    final localData = note.localData;
    final localDataStatus = NoteRepoMapper.localStatusToData(localData.status);
    NoteTableData noteData = NoteTableData(
      id: note.id,
      type: NoteTableType.voice,
      title: note.title,
      captures: captureDatas.map((c) => c.id).toList(),
      localData: LocalDataAll(status: localDataStatus),
      integratedData: IntegratedDataRepo(url: note.integratedData.url),
      createdAt: note.createdAt,
    );

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
    List<CaptureTableData> captureDatas = [];
    for (final capture in updatedNote.captures) {
      switch (capture) {
        case AudioFileCapture():
          captureDatas.add(CaptureTableData(
            id: capture.id,
            type: CaptureTableType.audio,
            createdAt: capture.createdAt,
            localData: CaptureLocalDataAll(
              status: NoteRepoMapper.captureLocalStatusToData(
                  capture.localData.status),
              filePath: capture.localData.filePath,
            ),
            typeData: CaptureTypeDataAll(
              transcription: capture.transcription,
            ),
          ));
          break;
        case UnknownCapture():
          captureDatas.add(CaptureTableData(
            id: capture.id,
            type: CaptureTableType.unknown,
            createdAt: capture.createdAt,
            localData: CaptureLocalDataAll(
              status: NoteRepoMapper.captureLocalStatusToData(
                  capture.localData.status),
            ),
            typeData: CaptureTypeDataAll(),
          ));
          break;
      }
    }

    final localDataStatus =
        NoteRepoMapper.localStatusToData(updatedNote.localData.status);
    NoteTableData noteData = NoteTableData(
      id: updatedNote.id,
      type: NoteTableType.voice,
      title: updatedNote.title,
      captures: captureDatas.map((c) => c.id).toList(),
      localData: LocalDataAll(status: localDataStatus),
      integratedData: IntegratedDataRepo(url: updatedNote.integratedData.url),
      createdAt: updatedNote.createdAt,
    );

    await db.transaction(() async {
      for (final captureData in captureDatas) {
        await db.into(db.captureTable).insertOnConflictUpdate(captureData);
      }
      await db.into(db.noteTable).insertOnConflictUpdate(noteData);
    });
  }

  Future<Note> getNoteByIdOrThrow(String id) async {
    final note = await getNoteById(id);
    if (note == null) {
      throw Exception("Note $id not found");
    }
    return note;
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

      return NoteRepoMapper.fromData(noteData, capturesData);
    }).first;
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
    return VoiceNote.fromDb(
      id: data.id,
      title: data.title,
      captures: captures.map((capture) {
        switch (capture.type) {
          case CaptureTableType.audio:
            return AudioFileCapture.fromDb(
              id: capture.id,
              createdAt: capture.createdAt,
              filePath: Optional(capture.localData.filePath),
              status: captureLocalStatusFromData(capture.localData.status),
              transcription: Optional(
                  capture.typeData.transcription), // TODO: set transcription
            );

          case CaptureTableType.unknown:
            return UnknownCapture.fromDb(
                id: capture.id,
                createdAt: capture.createdAt,
                localData: UnknownCaptureLocalData(
                    status:
                        captureLocalStatusFromData(capture.localData.status)));
        }
      }).toList(),
      integratedData: (url: data.integratedData.url),
      createdAt: data.createdAt,
    );
  }

  static NoteLocalStatus _localStatusFromData(NoteLocalStatusRepo status) {
    switch (status) {
      case NoteLocalStatusRepo.capturing:
        return NoteLocalStatus.capturing;
      case NoteLocalStatusRepo.captured:
        return NoteLocalStatus.captured;
      case NoteLocalStatusRepo.synced:
        return NoteLocalStatus.synced;
    }
  }

  static NoteLocalStatusRepo localStatusToData(NoteLocalStatus status) {
    switch (status) {
      case NoteLocalStatus.capturing:
        return NoteLocalStatusRepo.capturing;
      case NoteLocalStatus.captured:
        return NoteLocalStatusRepo.captured;
      case NoteLocalStatus.synced:
        return NoteLocalStatusRepo.synced;
    }
  }

  static CaptureLocalStatus captureLocalStatusFromData(
      CaptureLocalStatusRepo status) {
    switch (status) {
      case CaptureLocalStatusRepo.capturing:
        return CaptureLocalStatus.capturing;
      case CaptureLocalStatusRepo.captured:
        return CaptureLocalStatus.captured;
      case CaptureLocalStatusRepo.synced:
        return CaptureLocalStatus.synced;
    }
  }

  static CaptureLocalStatusRepo captureLocalStatusToData(
      CaptureLocalStatus status) {
    switch (status) {
      case CaptureLocalStatus.capturing:
        return CaptureLocalStatusRepo.capturing;
      case CaptureLocalStatus.captured:
        return CaptureLocalStatusRepo.captured;
      case CaptureLocalStatus.synced:
        return CaptureLocalStatusRepo.synced;
    }
  }
}
