import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/service/local_file_mutation_service.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:exnota/src/note/repo/id_generator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_mutation_service.g.dart';

@riverpod
class BlockMutationService extends _$BlockMutationService {
  @override
  FutureOr<void> build() {
    // noo-op
  }

  Future<LocalFile> createAudioBlock({required String extension}) {
    final now = DateTime.now();

    final block = Block(
      id: generateId(),
      type: BlockType.audio,
      properties: {},
      createdAt: now,
      lastEditedAt: now,
    );

    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    final file = transaction(() async {
      final file = await ref
          .read(localFileMutationServiceProvider.notifier)
          .createForAudioBlock(
            blockId: block.id,
            extension: extension,
            createdAt: now,
          );

      final blockRepo = BlockRepo(db);
      await blockRepo.create(block: block);

      return file;
    });

    return Future.value(file);
  }
}
