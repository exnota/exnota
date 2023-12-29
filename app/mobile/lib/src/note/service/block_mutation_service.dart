import 'package:exnota/src/lib/clock.dart';
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
    final now = ref.read(clockProvider).now();

    final idGenerator = ref.read(idGeneratorProvider);
    final blockId = idGenerator();
    final createOperation = Operation(type: OperationType.set, pointer: (
      id: blockId
    ), path: [], args: {
      Prop.id.toString(): blockId,
      Prop.type.toString(): BlockType.audio.toString(),
      Prop.createdAt.toString(): now.toIso8601String(),
      Prop.lastEditedAt.toString(): now.toIso8601String(),
    });

    final transaction = ref.read(transactionProvider);
    final file = transaction(() async {
      final file = await ref.read(localFileMutatorProvider).createForAudioBlock(
            blockId: blockId,
            extension: extension,
            createdAt: now,
          );

      final blockRepo = ref.read(blockRepoProvider);
      await blockRepo.executeTransaction(
          transaction: Transaction(operations: [createOperation]));

      return file;
    });

    return Future.value(file);
  }

  Future<void> setAudioBlockData(
      {required String blockId,
      required List<String> transcription,
      required String externalUrl}) async {
    final blockRepo = ref.read(blockRepoProvider);
    final now = ref.read(clockProvider).now();

    // Create content text blocks
    final createChildren = transcription.map((t) {
      final idGenerator = ref.read(idGeneratorProvider);
      final childId = idGenerator();
      return Operation(
        type: OperationType.set,
        pointer: (id: childId),
        path: [],
        args: {
          Prop.id.toString(): childId,
          Prop.type.toString(): BlockType.text.toString(),
          Prop.properties.toString(): {
            Property.title.toString(): [
              [t]
            ]
          },
          Prop.parentId.toString(): blockId,
          Prop.createdAt.toString(): now.toIso8601String(),
          Prop.lastEditedAt.toString(): now.toIso8601String(),
        },
      );
    }).toList();

    final listAfterChildren = createChildren.map((o) {
      return Operation(
        type: OperationType.listAfter,
        pointer: (id: blockId),
        path: [Prop.content.toString()],
        args: {
          ListAfterArg.id.toString(): o.pointer.id,
        },
      );
    }).toList();

    final updateParentUrl = Operation(
      type: OperationType.update,
      pointer: (id: blockId),
      path: [Prop.external.toString(), PrepExternal.url.toString()],
      args: {
        SingleVal.val.toString(): externalUrl,
      },
    );
    final updateParentEditedAt = Operation(
      type: OperationType.update,
      pointer: (id: blockId),
      path: [Prop.lastEditedAt.toString()],
      args: {
        SingleVal.val.toString(): now.toIso8601String(),
      },
    );

    final operations = List<Operation>.from(createChildren)
      ..addAll(listAfterChildren)
      ..addAll([updateParentUrl, updateParentEditedAt]);
    await blockRepo.executeTransaction(
        transaction: Transaction(
      operations: operations,
    ));
  }
}
