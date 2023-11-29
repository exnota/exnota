import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/data/drift/capture_table.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
import 'package:exnota/src/note/data/id_generator.dart';
import 'package:exnota/src/note/note.dart';

class NoteRepo {
  final AppDatabase db;

  NoteRepo(this.db);

  // TODO: Update to return VoiceNote once the fetching of captures is
  // implemented according to: https://drift.simonbinder.eu/docs/examples/relationships/#with-json-functions
  Future<void> createVoiceNote({required String filePath}) async {
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

    return db.transaction(() async {
      await db.into(db.captureTable).insertReturning(captureCompanion);
      await db.into(db.noteTable).insertReturning(noteCompanion);
      return;
    });
  }
}

//  class NoteRepoMapper {
//   static Note fromData(NoteTableData data) {
//     final localData = VoiceNoteLocalDataRepoMapper.fromJson(
//         jsonDecode(data.localData) as Map<String, dynamic>);
//     return VoiceNote(
//       id: data.id,
//       title: data.title,
//       captures: data.captures,
//       localData: localData,
//     );
//   }
// }

// TODO: Remove in favour of the one in note_table?
// Enum names are used in the database. So don't rename without handling the
// migration.
enum LocalDataRepoStatus {
  capturing(jsonName: "capturing"),
  captured(jsonName: "captured"),
  synced(jsonName: "synced");

  const LocalDataRepoStatus({required this.jsonName});

  final String jsonName;
}

class VoiceNoteLocalDataRepoMapper {
  static Map<String, dynamic> toJson(VoiceNoteLocalData data) {
    return {
      'filePath': data.filePath,
      'status': _statusToJson(data.status),
    };
  }

  static String _statusToJson(LocalStatus status) {
    switch (status) {
      case LocalStatus.capturing:
        return LocalDataRepoStatus.capturing.jsonName;
      case LocalStatus.captured:
        return LocalDataRepoStatus.captured.jsonName;
      case LocalStatus.synced:
        return LocalDataRepoStatus.synced.jsonName;
    }
  }

  static VoiceNoteLocalData fromJson(Map<String, dynamic> json) {
    return VoiceNoteLocalData(
      filePath: json['filePath'] as String,
      status: _statusFromJson(json['status'] as String),
    );
  }

  static LocalStatus _statusFromJson(String status) {
    if (status == LocalDataRepoStatus.capturing.jsonName) {
      return LocalStatus.capturing;
    } else if (status == LocalDataRepoStatus.captured.jsonName) {
      return LocalStatus.captured;
    } else if (status == LocalDataRepoStatus.synced.jsonName) {
      return LocalStatus.synced;
    } else {
      throw Exception("Unknown status: $status");
    }
  }
}
