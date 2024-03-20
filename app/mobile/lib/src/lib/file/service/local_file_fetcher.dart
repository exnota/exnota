import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_file_fetcher.g.dart';

/// Fetches a [LocalFile] by its id.
///
/// Throws an exception if the file is not found.
@riverpod
Future<LocalFile> getLocalFileByIdOrThrow(
    GetLocalFileByIdOrThrowRef ref, String id) async {
  final db = ref.read(databaseProvider);
  final repo = LocalFileRepo(db);
  return await repo.getByIdOrThrow(id: id);
}
// @riverpod
// Future<LocalFile?> getLocalFileByEntityId(GetLocalFileForEntityRef ref,
//     String entityId, EntityType entityType) async {
//   final db = ref.read(databaseProvider);
//   final repo = LocalFileRepo(db);
//   return await repo.getByEntityId(entityId: entityId, entityType: entityType);
// }
