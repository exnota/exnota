import 'package:exnota/src/block/repo/drift/destination_repo.dart';
import 'package:exnota/src/block/destination.dart';
import 'package:exnota/src/common/block/workspace_service.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'destination_lister.g.dart';

@riverpod
// Returns non-archived destinations for the active user.
class DestinationLister extends _$DestinationLister {
  @override
  Future<List<Destination>> build() async {
    final log = ref.watch(loggerProvider('DestinationLister'));
    log.debug('Building destination lister');

    final workspace = await ref.watch(activeWorkspaceProvider.future);
    if (workspace == null) {
      return [];
    }

    final repo = ref.watch(destinationRepoProvider);
    return await repo.listForWorkspace(workspaceId: workspace.id);
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

@riverpod
Future<Destination?> activeDestination(ActiveDestinationRef ref) async {
  final destinations = await ref.watch(destinationListerProvider.future);
  if (destinations.isEmpty) {
    return Future.value(null);
  }

  return destinations.first;
}

@riverpod
Destination? activeDestinationLazy(ActiveDestinationLazyRef ref) {
  final destinations = ref.watch(destinationListerProvider).value;
  if (destinations == null || destinations.isEmpty) {
    return null;
  }

  return destinations.first;
}
