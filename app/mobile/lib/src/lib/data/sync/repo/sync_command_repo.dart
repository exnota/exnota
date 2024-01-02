import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/repo/mapper.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_repo.g.dart';

@riverpod
SyncCommandRepo syncCommandRepo(SyncCommandRepoRef ref) {
  final db = ref.read(databaseProvider);
  return SyncCommandRepo(db);
}

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

  Future<SyncCommand> fetchById(int id) async {
    final query = db.select(db.syncCommandTable)..where((t) => t.id.equals(id));
    return await query
        .map<SyncCommand>(SyncCommandRepoMapper.fromData)
        .getSingle();
  }

  Future<List<SyncCommand>> fetchByEntityId(String entityId) async {
    final query = db.select(db.syncCommandTable)
      ..where((t) => t.entityId.equals(entityId));
    return await query.map<SyncCommand>(SyncCommandRepoMapper.fromData).get();
  }

  Future<List<SyncCommand>> fetchByRootEntityId(String rootEntityId) async {
    final query = db.select(db.syncCommandTable)
      ..where((t) => t.rootEntityId.equals(rootEntityId));
    return await query.map<SyncCommand>(SyncCommandRepoMapper.fromData).get();
  }

  Future<void> createCommand({required SyncCommand command}) async {
    SyncCommandTableCompanion toInsert = SyncCommandRepoMapper.toData(command);
    await db.into(db.syncCommandTable).insert(toInsert);
  }

  // update status of command
  Future<void> setStatus(
      {required int id,
      required SyncCommandStatus status,
      required DateTime updatedAt}) async {
    final query = db.update(db.syncCommandTable)
      ..where((tbl) => tbl.id.equals(id));
    await query.write(SyncCommandTableCompanion(
        status: Value(SyncCommandRepoMapper.statusToData(status)),
        updatedAt: Value(updatedAt)));
  }
}
