import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/lib/data/sync/sync_command_table.dart';

class SyncCommandRepo {
  final AppDatabase db;

  SyncCommandRepo(this.db);

  Future<List<SyncCommand>> fetchAll({SyncCommandStatus? status}) async {
    if (status != null) {
      final query = db.select(db.syncCommandTable)
        ..where((t) => t.status.equalsValue(_statusToDb(status)));

      return query.map<SyncCommand>(_toDomain).get();
    }
    final all = await db.select(db.syncCommandTable).get();
    return all.map(_toDomain).toList();
  }

  Stream<List<SyncCommand>> fetchAllStream({SyncCommandStatus? status}) {
    if (status != null) {
      final query = db.select(db.syncCommandTable)
        ..where((t) => t.status.equalsValue(_statusToDb(status)));

      return query.map<SyncCommand>(_toDomain).watch();
    }
    return db.select(db.syncCommandTable).map<SyncCommand>(_toDomain).watch();
  }

  Future<void> createCreateAudioNoteSyncCommand(
      {required String noteId,
      required String captureId,
      required String filePath}) async {
    SyncCommandTableCompanion toInsert = SyncCommandTableCompanion.insert(
        type: SyncCommandRepoType.createAudioNote,
        entityId: noteId,
        data: json.encode(CreateAudioNoteSyncCommand.dataToJson(
            capture: (id: captureId, filePath: filePath))),
        status: SyncCommandRepoStatus.waiting);
    await db.into(db.syncCommandTable).insert(toInsert);
  }

  // update status of command
  Future<void> setStatus(int id, SyncCommandStatus status) async {
    db.update(db.syncCommandTable)
      ..where((tbl) => tbl.id.equals(id))
      ..write(SyncCommandTableCompanion(status: Value(_statusToDb(status))));
  }

  SyncCommand _toDomain(SyncCommandTableData fromDb) {
    final data = jsonDecode(fromDb.data);
    switch (fromDb.type) {
      case SyncCommandRepoType.createAudioNote:
        return CreateAudioNoteSyncCommand.fromDb(
            id: fromDb.id,
            entityId: fromDb.entityId,
            data: data as Map<String, dynamic>,
            status: _statusFromDb(fromDb.status));
      default:
        throw Exception('Unknown command type');
    }
  }

  SyncCommandRepoStatus _statusToDb(SyncCommandStatus status) {
    switch (status) {
      case SyncCommandStatus.waiting:
        return SyncCommandRepoStatus.waiting;
      case SyncCommandStatus.running:
        return SyncCommandRepoStatus.running;
      case SyncCommandStatus.complete:
        return SyncCommandRepoStatus.complete;
    }
  }

  SyncCommandStatus _statusFromDb(SyncCommandRepoStatus status) {
    switch (status) {
      case SyncCommandRepoStatus.waiting:
        return SyncCommandStatus.waiting;
      case SyncCommandRepoStatus.running:
        return SyncCommandStatus.running;
      case SyncCommandRepoStatus.complete:
        return SyncCommandStatus.complete;
    }
  }
}
