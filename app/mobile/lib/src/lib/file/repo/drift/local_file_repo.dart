import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_repo_mapper.dart';
import 'package:exnota/src/lib/log/logger.dart';

class LocalFileRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  LocalFileRepo(this.db);

  Stream<List<LocalFile>> listWatch() {
    final query = db.select(db.localFileTable);
    query.orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.map(LocalFileRepoMapper.fromRepo).watch();
  }

  Future<LocalFile?> getByEntityId(
      {required String entityId, required EntityType entityType}) async {
    final entityTypeRepo = LocalFileRepoMapper.typeToRepo(entityType);

    final query = db.select(db.localFileTable)
      ..where((t) =>
          t.entityId.equals(entityId) &
          t.entityType.equals(entityTypeRepo.toString()));
    final result = await query.getSingleOrNull();
    if (result == null) {
      logger.error(
          'LocalFileRepo.getByEntityId: No local file found with entityId '
          '$entityId and entityType $entityType');
      return null;
    }
    return LocalFileRepoMapper.fromRepo(result);
  }

  Future<void> create({required LocalFile file}) async {
    final fileData = LocalFileRepoMapper.toRepo(file);
    await db.into(db.localFileTable).insert(fileData);
  }
}
