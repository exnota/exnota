import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/local_file.dart';
import 'package:exnota/src/note/repo/file/local_file_service.dart';
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
    // Backend command: Create block with ID, etc
    final block = Block(
      id: generateId(),
      type: BlockType.audio,
      properties: {},
      createdAt: now,
      lastEditedAt: now,
    );
    final localFileService = ref.read(localFileServiceProvider);
    final path = localFileService.generateAudioBlockFilePath(
        blockId: block.id, extension: extension);
    final file = LocalFile(
        id: generateId(),
        blockId: block.id,
        path: path,
        createdAt: now,
        syncedAt: now);
    // TODO: Persist in transaction
    return Future.value(file);
  }
}
