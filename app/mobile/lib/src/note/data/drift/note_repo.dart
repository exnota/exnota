import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/capture.dart';
import 'package:exnota/src/note/data/drift/capture_table.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
import 'package:exnota/src/note/note.dart';
import 'package:drift/extensions/json1.dart';

class NoteRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  NoteRepo(this.db);

  Future<void> createVoiceNote({required Note note}) async {
    List<CaptureTableData> captureDatas = [];
    for (final capture in note.captures) {
      switch (capture) {
        case AudioFileCapture():
          captureDatas.add(CaptureTableData(
            id: capture.id,
            type: CaptureTableType.audio,
          ));
          break;
        case UnknownCapture():
          captureDatas.add(CaptureTableData(
            id: capture.id,
            type: CaptureTableType.unknown,
          ));
          break;
      }
    }

    String? filePath;
    final localData = note.localData;
    if (localData is VoiceNoteLocalData) {
      filePath = localData.filePath;
    }
    final localDataStatus = NoteRepoMapper.localStatusToData(localData.status);
    NoteTableData noteData = NoteTableData(
      id: note.id,
      type: NoteTableType.voice,
      title: note.title,
      captures: captureDatas.map((c) => c.id).toList(),
      localData: LocalDataAll(status: localDataStatus, filePath: filePath),
      integratedData: IntegratedDataRepo(url: note.integratedData.url),
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
          ));
          break;
        case UnknownCapture():
          captureDatas.add(CaptureTableData(
            id: capture.id,
            type: CaptureTableType.unknown,
          ));
          break;
      }
    }

    String? filePath;
    final localData = updatedNote.localData;
    if (localData is VoiceNoteLocalData) {
      filePath = localData.filePath;
    }
    final localDataStatus = NoteRepoMapper.localStatusToData(localData.status);

    NoteTableData noteData = NoteTableData(
      id: updatedNote.id,
      type: NoteTableType.voice,
      title: updatedNote.title,
      captures: captureDatas.map((c) => c.id).toList(),
      localData: LocalDataAll(status: localDataStatus, filePath: filePath),
      integratedData: IntegratedDataRepo(url: updatedNote.integratedData.url),
    );

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
    final filePath = data.localData.filePath;
    final localData = VoiceNoteLocalData(
      filePath: filePath,
      status: _localStatusFromData(data.localData.status),
    );

    return VoiceNote.fromDb(
      id: data.id,
      title: data.title,
      captures: captures.map((capture) {
        switch (capture.type) {
          case CaptureTableType.audio:
            return AudioFileCapture(
              id: capture.id,
            );

          case CaptureTableType.unknown:
            return UnknownCapture(
              id: capture.id,
            );
        }
      }).toList(),
      localData: localData,
      integratedData: (url: data.integratedData.url),
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

  static LocalStatusRepo localStatusToData(LocalStatus status) {
    switch (status) {
      case LocalStatus.capturing:
        return LocalStatusRepo.capturing;
      case LocalStatus.captured:
        return LocalStatusRepo.captured;
      case LocalStatus.synced:
        return LocalStatusRepo.synced;
    }
  }
}
