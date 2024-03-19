import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo_mapper.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';

class SyncCommandRepo {
  final AppDatabase db;

  SyncCommandRepo(this.db);

  // Future<List<SyncCommand>> fetchAll({SyncCommandStatus? status}) async {
  //   if (status != null) {
  //     final query = db.select(db.syncCommandTable)
  //       ..where((t) =>
  //           t.status.equalsValue(SyncCommandRepoMapper.statusToData(status)));

  //     return query.map<SyncCommand>(SyncCommandRepoMapper.fromData).get();
  //   }
  //   final all = await db.select(db.syncCommandTable).get();
  //   return all.map(SyncCommandRepoMapper.fromData).toList();
  // }

  // Stream<List<SyncCommand>> fetchAllStream({SyncCommandStatus? status}) {
  //   if (status != null) {
  //     final query = db.select(db.syncCommandTable)
  //       ..where((t) =>
  //           t.status.equalsValue(SyncCommandRepoMapper.statusToData(status)));

  //     return query.map<SyncCommand>(SyncCommandRepoMapper.fromData).watch();
  //   }
  //   return db
  //       .select(db.syncCommandTable)
  //       .map<SyncCommand>(SyncCommandRepoMapper.fromData)
  //       .watch();
  // }

  // Future<SyncCommand> fetchById(int id) async {
  //   final query = db.select(db.syncCommandTable)..where((t) => t.id.equals(id));
  //   return await query
  //       .map<SyncCommand>(SyncCommandRepoMapper.fromData)
  //       .getSingle();
  // }

  // Future<List<SyncCommand>> fetchByEntityId(String entityId) async {
  //   final query = db.select(db.syncCommandTable)
  //     ..where((t) => t.entityId.equals(entityId));
  //   return await query.map<SyncCommand>(SyncCommandRepoMapper.fromData).get();
  // }

  // Future<List<SyncCommand>> fetchByRootEntityId(String rootEntityId) async {
  //   final query = db.select(db.syncCommandTable)
  //     ..where((t) => t.rootEntityId.equals(rootEntityId));
  //   return await query.map<SyncCommand>(SyncCommandRepoMapper.fromData).get();
  // }

  Future<void> createCommand({required SyncCommand command}) async {
    SyncCommandTableData toInsert = SyncCommandRepoMapper.toRepo(command);
    await db.into(db.syncCommandTable).insert(toInsert);
  }

  Future<void> setRunning(
      {required String id, required DateTime timestamp}) async {
    final query = db.update(db.syncCommandTable)
      ..where((tbl) => tbl.id.equals(id));
    final companion = SyncCommandTableCompanion(
        status: Value(
            SyncCommandRepoMapper.statusToData(SyncCommandStatus.running)),
        updatedAt: Value(timestamp),
        startedAt: Value(timestamp),
        result: const Value(null));
    await query.write(companion);
  }

  Future<void> setErrored(
      {required String id,
      required SyncCommandError error,
      required DateTime timestamp}) async {
    final query = db.update(db.syncCommandTable)
      ..where((tbl) => tbl.id.equals(id));
    final companion = SyncCommandTableCompanion(
        status:
            Value(SyncCommandRepoMapper.statusToData(SyncCommandStatus.error)),
        updatedAt: Value(timestamp),
        result: Value(error.toString()));
    await query.write(companion);
  }

  Future<void> setComplete(
      {required String id, required DateTime timestamp}) async {
    final query = db.update(db.syncCommandTable)
      ..where((tbl) => tbl.id.equals(id));
    final companion = SyncCommandTableCompanion(
        status: Value(
            SyncCommandRepoMapper.statusToData(SyncCommandStatus.complete)),
        updatedAt: Value(timestamp),
        result: const Value('Success'));
    await query.write(companion);
  }

  /// Returns the oldest waiting job for the user.
  ///
  /// If there's a running job, it's returned if it's older than
  /// [runningTimeout]. If it's younger, then it's assumed to still be running
  /// and null is returned.
  ///
  /// It's the caller's responsibility to make sure the user ID is for the
  /// active user.
  Future<SyncCommand?> fetchNextForUser(
      {required String userId, required Duration runningTimeout}) async {
    return await db.transaction(() async {
      // Check for oldest running job
      final queryOldestRunning = db.select(db.syncCommandTable)
        ..where((t) => t.userId.equals(userId))
        ..where((t) => t.status.equals(
            SyncCommandRepoMapper.statusToData(SyncCommandStatus.running)))
        ..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
        ])
        ..limit(1);
      final oldestRunning = await queryOldestRunning
          .map<SyncCommand>(SyncCommandRepoMapper.fromData)
          .getSingleOrNull();

      // If oldest running is more than [runningTimeout] old, then return it so
      // it can be restarted.
      if (oldestRunning != null) {
        final now = DateTime.now();
        if (oldestRunning.startedAt!.add(runningTimeout).isBefore(now)) {
          return oldestRunning;
        } else {
          // Assume it's still running
          return null;
        }
      }

      // Return next waiting
      final queryNextWaiting = db.select(db.syncCommandTable)
        ..where((t) => t.userId.equals(userId))
        ..where((t) => t.status.equals(
            SyncCommandRepoMapper.statusToData(SyncCommandStatus.waiting)))
        ..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
        ])
        ..limit(1);
      final result = await queryNextWaiting
          .map<SyncCommand>(SyncCommandRepoMapper.fromData)
          .getSingleOrNull();
      return result;
    });
  }

  /// Watches for commands for the current active user (by checking the user_auth table's `active` column).
  ///
  /// If there is a running command, it will be returned if it's older than [runningTimeout]. If it's younger, then it's assumed to still be running and null is returned.
  ///
  /// If there is no running command, any with 'waiting' status will be returned.
  Stream<List<SyncCommand>> watchNextForActiveUser(
      {required Duration runningTimeout}) {
    // TODO: Check running first, as above.

    final queryNextWaiting = db.select(db.syncCommandTable).join([
      innerJoin(db.userAuthTable,
          db.userAuthTable.userId.equalsExp(db.syncCommandTable.userId),
          useColumns: false)
    ])
      ..where(db.userAuthTable.active.equals(true))
      ..where(db.syncCommandTable.status.equals(
          SyncCommandRepoMapper.statusToData(SyncCommandStatus.waiting)))
      ..orderBy([
        OrderingTerm(
            expression: db.syncCommandTable.createdAt, mode: OrderingMode.asc)
      ]);
    final result = queryNextWaiting.watch().map((rows) {
      return rows.map((row) {
        return SyncCommandRepoMapper.fromData(
            row.readTable(db.syncCommandTable));
      }).toList();
    });
    return result;
  }
}
