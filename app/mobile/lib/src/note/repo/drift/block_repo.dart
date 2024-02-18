import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo_mapper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_repo.g.dart';

@riverpod
BlockRepo blockRepo(BlockRepoRef ref) {
  final db = ref.watch(databaseProvider);
  return BlockRepo(db);
}

class BlockRepo {
  final AppDatabase db;

  BlockRepo(this.db);

  Stream<List<Block>> listWatch({required String userId}) {
    final query = db.select(db.blockTable)
      ..where((tbl) => tbl.user.equals(userId));
    query.orderBy([(row) => OrderingTerm.desc(row.userCreated)]);
    return query.map(BlockRepoMapper.fromRepo).watch();
  }

  Future<List<Block>> list() async {
    final query = db.select(db.blockTable);
    return await query.map(BlockRepoMapper.fromRepo).get();
  }
}
