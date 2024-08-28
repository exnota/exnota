import 'package:exnota/src/block/repo/drift/workspace_repo.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_lister.g.dart';

@riverpod
// Returns all non-archived workspaces for the active user.
class WorkspaceLister extends _$WorkspaceLister {
  @override
  Future<List<Workspace>> build() async {
    final log = ref.watch(loggerProvider('WorkspaceLister'));
    log.debug('Building workspace lister');

    final activeUserId = ref.read(activeUserIdOrThrowSyncProvider);

    final repo = ref.watch(workspaceRepoProvider);
    return await repo.listUnarchived(userId: activeUserId);
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

@riverpod
// Returns the first non-archived workspace for the active user.
Future<Workspace?> activeWorkspace(ActiveWorkspaceRef ref) async {
  final workspaces = await ref.watch(workspaceListerProvider.future);
  if (workspaces.isNotEmpty) {
    return workspaces.first;
  } else {
    return null;
  }
}
