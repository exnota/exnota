import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_repo.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_file_mutator.g.dart';

@riverpod
LocalFileMutator localFileMutator(LocalFileMutatorRef ref) {
  return LocalFileMutator(ref);
}

class LocalFileMutator {
  final Ref ref;

  LocalFileMutator(this.ref);

  Future<LocalFile> createForAudioBlock(
      {required String blockId,
      required String extension,
      required DateTime createdAt}) async {
    final path = await ref
        .read(localFilePathServiceProvider)
        .generateAudioBlockFilePath(blockId: blockId, extension: extension);
    final file = LocalFile(
        id: generateId(),
        entityType: EntityType.block,
        entityId: blockId,
        path: path,
        createdAt: createdAt,
        syncedAt: null);

    final db = ref.read(databaseProvider);
    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      final localFileRepo = LocalFileRepo(db);
      await localFileRepo.create(file: file);
    });

    return file;
  }
}
