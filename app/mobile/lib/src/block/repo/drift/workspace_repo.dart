import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/repo/drift/workspace_repo_mapper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_repo.g.dart';

@riverpod
WorkspaceRepo workspaceRepo(WorkspaceRepoRef ref) {
  final db = ref.watch(databaseProvider);
  return WorkspaceRepo(db);
}

class WorkspaceRepo {
  final AppDatabase db;
  final _log = Logger(context: 'WorkspaceRepo');

  WorkspaceRepo(this.db);

  Future<List<Workspace>> listUnarchived({required String userId}) async {
    final query = db.select(db.workspaceTable)
      ..where((tbl) => tbl.archived.isNull())
      ..where((tbl) => tbl.user.equals(userId));
    return await query.map(WorkspaceRepoMapper.fromRepo).get();
  }

  Future<void> upsert(Workspace workspace) async {
    _log.debug('Upsert: Starting for workspace ${workspace.id}');
    await db.transaction(() async {
      final query = db.select(db.workspaceTable)
        ..where((tbl) => tbl.id.equals(workspace.id));
      final existing =
          await query.map(WorkspaceRepoMapper.fromRepo).getSingleOrNull();
      if (existing != null) {
        _log.debug('Upsert: Updating existing workspace ${workspace.id}');
      } else {
        _log.debug('Upsert: Inserting new workspace ${workspace.id}');
      }

      await db
          .into(db.workspaceTable)
          .insertOnConflictUpdate(WorkspaceRepoMapper.toRepo(workspace));
    });
  }

  Future<Workspace?> fetchById(String id) async {
    final query = db.select(db.workspaceTable)
      ..where((tbl) => tbl.id.equals(id));
    return await query.map(WorkspaceRepoMapper.fromRepo).getSingleOrNull();
  }
}
