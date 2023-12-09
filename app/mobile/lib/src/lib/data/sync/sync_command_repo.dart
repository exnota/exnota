import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/mapper.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';

class SyncCommandRepo {
  final AppDatabase db;

  SyncCommandRepo(this.db);

  Future<List<SyncCommand>> fetchAll({SyncCommandStatus? status}) async {
    if (status != null) {
      final query = db.select(db.syncCommandTable)
        ..where((t) =>
            t.status.equalsValue(SyncCommandRepoMapper.statusToData(status)));

      return query.map<SyncCommand>(SyncCommandRepoMapper.fromData).get();
    }
    final all = await db.select(db.syncCommandTable).get();
    return all.map(SyncCommandRepoMapper.fromData).toList();
  }

  Stream<List<SyncCommand>> fetchAllStream({SyncCommandStatus? status}) {
    if (status != null) {
      final query = db.select(db.syncCommandTable)
        ..where((t) =>
            t.status.equalsValue(SyncCommandRepoMapper.statusToData(status)));

      return query.map<SyncCommand>(SyncCommandRepoMapper.fromData).watch();
    }
    return db
        .select(db.syncCommandTable)
        .map<SyncCommand>(SyncCommandRepoMapper.fromData)
        .watch();
  }

  Future<void> createCommand({required SyncCommand command}) async {
    SyncCommandTableCompanion toInsert =
        SyncCommandRepoMapper.toDataInsert(command);
    await db.into(db.syncCommandTable).insert(toInsert);
  }

  // update status of command
  Future<void> setStatus(int id, SyncCommandStatus status) async {
    db.update(db.syncCommandTable)
      ..where((tbl) => tbl.id.equals(id))
      ..write(SyncCommandTableCompanion(
          status: Value(SyncCommandRepoMapper.statusToData(status))));
  }
}
