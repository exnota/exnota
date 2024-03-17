import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_repo_mapper.dart';
import 'package:exnota/src/lib/log/logger.dart';

class LocalFileRepo {
  static final Logger _log = Logger(context: 'LocalFileRepo');

  final AppDatabase db;

  LocalFileRepo(this.db);

  // Stream<List<LocalFile>> listWatch() {
  //   final query = db.select(db.localFileTable);
  //   query.orderBy([(row) => OrderingTerm.desc(row.created)]);
  //   return query.map(LocalFileRepoMapper.fromRepo).watch();
  // }

  // Future<LocalFile?> getByEntityId(
  //     {required String entityId, required EntityType entityType}) async {
  //   final entityTypeRepo = LocalFileRepoMapper.entityTypeToRepo(entityType);

  //   final query = db.select(db.localFileTable)
  //     ..where((t) =>
  //         t.entityId.equals(entityId) &
  //         t.entityType.equals(entityTypeRepo.toString()));
  //   final result = await query.getSingleOrNull();
  //   if (result == null) {
  //     logger.error(
  //         'LocalFileRepo.getByEntityId: No local file found with entityId '
  //         '$entityId and entityType $entityType');
  //     return null;
  //   }
  //   return LocalFileRepoMapper.fromRepo(result);
  // }

  Future<LocalFile> getByIdOrThrow({required String id}) async {
    final query = db.select(db.localFileTable)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    if (result == null) {
      _log.error('LocalFileRepo.getById: No local file found with id $id');
      throw Exception('No local file found with id $id');
    }
    return LocalFileRepoMapper.fromRepo(result);
  }

  Future<void> create({required LocalFile file}) async {
    _log.debug('create: Start');
    final fileData = LocalFileRepoMapper.toRepo(file);
    await db.into(db.localFileTable).insert(fileData);
    _log.debug('create: End');
  }

  Future<void> update({required LocalFile file}) async {
    _log.debug('update: Start');
    final fileData = LocalFileRepoMapper.toRepo(file);
    await db.update(db.localFileTable).replace(fileData);
    _log.debug('update: End');
  }
}
