import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo_mapper.dart';

class BlockRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  BlockRepo(this.db);

  Stream<List<Block>> listWatch() {
    final query = db.select(db.blockTable);
    query.orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.map(BlockRepoMapper.fromRepo).watch();
  }

  Future<void> create({required Block block}) async {
    final blockData = BlockRepoMapper.toRepo(block);
    await db.into(db.blockTable).insert(blockData);
  }
}
