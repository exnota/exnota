import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/block.dart';
import 'package:exnota/src/block/repo/drift/block_repo_mapper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_repo.g.dart';

@riverpod
BlockRepo blockRepo(BlockRepoRef ref) {
  final db = ref.watch(databaseProvider);
  return BlockRepo(db);
}

class BlockRepo {
  final AppDatabase db;
  final _log = Logger(context: 'BlockRepo');

  BlockRepo(this.db);

  Stream<List<Block>> listWatch({required String userId}) {
    _log.debug('listWatch starting for user $userId');
    final query = db.select(db.blockTable)
      ..where((tbl) => tbl.user.equals(userId));
    query.orderBy([(row) => OrderingTerm.desc(row.userCreated)]);
    return query.map(BlockRepoMapper.fromRepo).watch();
  }

  Future<void> upsert(Block block) async {
    await db.transaction(() async {
      final query = db.select(db.blockTable)
        ..where((tbl) => tbl.id.equals(block.id));
      final existing =
          await query.map(BlockRepoMapper.fromRepo).getSingleOrNull();
      if (existing != null) {
        _log.debug('Upsert: Updating existing block ${block.id}');
      } else {
        _log.debug('Upsert: Inserting new block ${block.id}');
      }

      await db
          .into(db.blockTable)
          .insertOnConflictUpdate(BlockRepoMapper.toRepo(block));
    });
  }

  Future<Block?> fetchById(String id) async {
    final query = db.select(db.blockTable)..where((tbl) => tbl.id.equals(id));
    return await query.map(BlockRepoMapper.fromRepo).getSingleOrNull();
  }
}
