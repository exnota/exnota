import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_table.dart';

class LocalFileRepoMapper {
  static LocalFileTableData toRepo(LocalFile file) {
    return LocalFileTableData(
      id: file.id,
      entityType: _typeToRepo(file.entityType),
      entityId: file.entityId,
      path: file.path,
      createdAt: file.createdAt,
      syncedAt: file.syncedAt,
    );
  }

  static LocalFile fromRepo(LocalFileTableData file) {
    return LocalFile(
      id: file.id,
      entityType: _typeFromRepo(file.entityType),
      entityId: file.entityId,
      path: file.path,
      createdAt: file.createdAt,
      syncedAt: file.syncedAt,
    );
  }

  static EntityTypeRepo _typeToRepo(EntityType type) {
    switch (type) {
      case EntityType.block:
        return EntityTypeRepo.block;
    }
  }

  static EntityType _typeFromRepo(EntityTypeRepo type) {
    switch (type) {
      case EntityTypeRepo.block:
        return EntityType.block;
    }
  }
}
