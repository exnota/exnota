import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_lister.g.dart';

const apiPageSize = 5;

@riverpod
class BlockLister extends _$BlockLister {
  DateTime? _timestampApiHasNoMore;

  @override
  Future<Blocks> build() async {
    // - returns { blocks: [], isLoading, hasMore = timestampNoMoreFound == null }
    // - TODO: how to calc isLoading, hasMore
    // - returns all blocks from DB
    final repo = ref.read(blockRepoProvider);
    final blocks = await repo.list();

    final pb = ref.watch(pocketBaseProvider);
    if (blocks.length >= apiPageSize) {
      pb
          .collection('block')
          .getList(page: 1, perPage: apiPageSize, sort: 'userCreated')
          .then((value) {
        print('${value.items.length} results');
        print('${value.totalItems} total');
      });
      return Blocks(blocks: blocks, isLoading: false);
    } else {
      pb
          .collection('block')
          .getList(page: 1, perPage: apiPageSize, sort: 'userCreated')
          .then((value) {
        print('${value.items.length} results');
        print('${value.totalItems} total');
      });
      _timestampApiHasNoMore = DateTime.now();
      return Blocks(blocks: blocks, isLoading: true);
    }

    // - if number of blocks > apiPageSize, timestampNoMoreFound = null
    // - if number of blocks < apiPageSize, isLoading=true and fetch batch of apiPageSize
    //     - set isLoading=false after done, and timestampNoMoreFound date/null depending on
  }

  void loadMore() {
    // TODO:
  }
}

class Blocks {
  final List<Block> blocks;
  final bool isLoading;

  Blocks({required this.blocks, required this.isLoading});
}
