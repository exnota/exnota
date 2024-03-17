import 'package:exnota/src/context/device/local_file_path_service.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_repo.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalFileMutator {
  final ProviderContainer _container;

  LocalFileMutator(this._container);

  Future<LocalFile> createForAudioBlock(
      {required String extension, required Status status}) async {
    final id = generateId();
    final path = await _container
        .read(localFilePathServiceProvider)
        .generateAudioBlockFilePath(localFileId: id, extension: extension);
    final file = LocalFile(
        id: id,
        fileType: FileType.audioRecording,
        status: status,
        path: path,
        entityType: EntityType.block,
        created: DateTime.now());

    final db = _container.read(databaseProvider);
    final transaction = _container.read(transactionProvider);
    await transaction(() async {
      final localFileRepo = LocalFileRepo(db);
      await localFileRepo.create(file: file);
    });

    return file;
  }

  Future<void> updateStatus(
      {required String id, required Status status}) async {
    final db = _container.read(databaseProvider);
    final transaction = _container.read(transactionProvider);
    await transaction(() async {
      final localFileRepo = LocalFileRepo(db);
      final existing = await localFileRepo.getByIdOrThrow(id: id);
      final updated = existing.copyWith(status: status);
      await localFileRepo.update(file: updated);
    });
  }

  Future<void> addEntityId(
      {required String id, required String entityId}) async {
    final db = _container.read(databaseProvider);
    final transaction = _container.read(transactionProvider);
    await transaction(() async {
      final localFileRepo = LocalFileRepo(db);
      final existing = await localFileRepo.getByIdOrThrow(id: id);
      final updated = existing.copyWith(entityId: entityId);
      await localFileRepo.update(file: updated);
    });
  }
}
