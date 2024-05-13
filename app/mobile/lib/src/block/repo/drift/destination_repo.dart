import 'package:exnota/src/block/destination.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/repo/drift/destination_repo_mapper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'destination_repo.g.dart';

@riverpod
DestinationRepo destinationRepo(DestinationRepoRef ref) {
  final db = ref.watch(databaseProvider);
  return DestinationRepo(db);
}

class DestinationRepo {
  final AppDatabase db;
  final _log = Logger(context: 'DestinationRepo');

  DestinationRepo(this.db);

  Future<List<Destination>> listForWorkspace(
      {required String workspaceId}) async {
    final query = db.select(db.destinationTable)
      ..where((tbl) => tbl.workspace.equals(workspaceId));
    final results = await query.map(DestinationRepoMapper.fromRepo).get();
    return results.toList();
  }

  Future<void> upsert(Destination destination) async {
    await db.transaction(() async {
      final query = db.select(db.destinationTable)
        ..where((tbl) => tbl.id.equals(destination.id));
      final existing =
          await query.map(DestinationRepoMapper.fromRepo).getSingleOrNull();
      if (existing != null) {
        _log.debug('Upsert: Updating existing destination ${destination.id}');
      } else {
        _log.debug('Upsert: Inserting new destination ${destination.id}');
      }

      await db
          .into(db.destinationTable)
          .insertOnConflictUpdate(DestinationRepoMapper.toRepo(destination));
    });
  }
}
