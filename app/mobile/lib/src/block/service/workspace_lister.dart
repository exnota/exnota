import 'package:exnota/src/block/repo/drift/workspace_repo.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_lister.g.dart';

@riverpod
// Returns non-archived workspaces
Future<List<Workspace>> workspaceLister(WorkspaceListerRef ref) async {
  final log = ref.watch(loggerProvider('WorkspaceLister'));
  log.debug('Building workspace lister');

  final repo = ref.watch(workspaceRepoProvider);
  return await repo.listUnarchived();
}
