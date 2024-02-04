import 'package:exnota/src/account/user/service/auth_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_lister.g.dart';
part 'block_lister.freezed.dart';

@freezed
class PBBlock with _$PBBlock {
  const factory PBBlock({
    required String id,
    required String title,
  }) = _PBBlock;
}

@riverpod
class BlockLister extends _$BlockLister {
  @override
  Future<List<PBBlock>> build() async {
    final pb = ref.watch(pocketBaseServiceProvider);
    final resultList =
        await pb.collection('block').getFullList(sort: '-created');

    return resultList
        .map((e) => PBBlock(id: e.id, title: e.data['title']))
        .toList();
  }

  void refresh() {
    ref.invalidateSelf();
  }
}
