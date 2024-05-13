import 'package:exnota/src/block/repo/drift/destination_repo.dart';
import 'package:exnota/src/block/destination.dart';
import 'package:exnota/src/common/block/workspace_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'destination_lister.g.dart';

@riverpod
// Returns non-archived destinations for the active user.
Future<List<Destination>> destinationLister(DestinationListerRef ref) async {
  final log = ref.watch(loggerProvider('DestinationLister'));
  log.debug('Building destination lister');

  final workspace = await ref.watch(activeWorkspaceProvider.future);
  if (workspace == null) {
    return [];
  }

  final repo = ref.watch(destinationRepoProvider);
  return await repo.listForWorkspace(workspaceId: workspace.id);
}
