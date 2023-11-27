import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:exnota/database.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/note/data/sync/create_audio_note_sync_command.dart';
import 'package:exnota/src/note/data/sync/sync_command_table.dart';

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

  Future<void> create(SyncCommand cmd) async {
    SyncCommandRepoType type;
    switch (cmd.runtimeType) {
      case CreateAudioNoteSyncCommand:
        type = SyncCommandRepoType.createAudioNote;
        break;
      default:
        throw Exception('Unknown command type');
    }
    final data = cmd.dataToJson();
    SyncCommandTableCompanion toInsert = SyncCommandTableCompanion.insert(
        type: type,
        entityId: cmd.entityId,
        data: jsonEncode(data),
        status: _statusToDb(cmd.status));
    await db.into(db.syncCommandTable).insert(toInsert);
  }

  // update status of command
  Future<void> setStatus(String id, SyncCommandStatus status) async {
    db.update(db.syncCommandTable)
      ..where((tbl) => tbl.entityId.equals(id))
      ..write(SyncCommandTableCompanion(status: Value(_statusToDb(status))));
  }

  SyncCommand _toDomain(SyncCommandTableData fromDb) {
    final data = jsonDecode(fromDb.data);
    switch (fromDb.type) {
      case SyncCommandRepoType.createAudioNote:
        return CreateAudioNoteSyncCommand.fromJson(
            entityId: fromDb.entityId,
            json: data as Map<String, dynamic>,
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
