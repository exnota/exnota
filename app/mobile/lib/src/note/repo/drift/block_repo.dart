import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo_mapper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_repo.g.dart';

@riverpod
BlockRepo blockRepo(BlockRepoRef ref) {
  final db = ref.read(databaseProvider);
  return BlockRepo(db);
}

class BlockRepo {
  final AppDatabase db;

  BlockRepo(this.db);

  Future<List<Block>> list() async {
    final query = db.select(db.blockTable);
    return await query.map(BlockRepoMapper.fromRepo).get();
  }
}
