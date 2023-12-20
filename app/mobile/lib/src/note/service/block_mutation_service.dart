import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/service/local_file_mutation_service.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/operation.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:exnota/src/note/repo/id_generator.dart';
import 'package:exnota/src/note/transaction.dart';
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

    final blockId = generateId();
    final createOperation = Operation(type: OperationType.set, pointer: (
      id: blockId
    ), path: [], args: {
      ArgKey.id.toString(): blockId,
      ArgKey.type.toString(): BlockType.audio.toString(),
      ArgKey.createdAt.toString(): now.toIso8601String(),
      ArgKey.lastEditedAt.toString(): now.toIso8601String(),
    });

    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    final file = transaction(() async {
      final file = await ref
          .read(localFileMutationServiceProvider.notifier)
          .createForAudioBlock(
            blockId: blockId,
            extension: extension,
            createdAt: now,
          );

      final blockRepo = BlockRepo(db);
      await blockRepo.executeTransaction(
          transaction: Transaction(operations: [createOperation]));

      return file;
    });

    return Future.value(file);
  }
}
