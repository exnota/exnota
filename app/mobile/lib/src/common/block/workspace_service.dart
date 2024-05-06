import 'dart:async';

import 'package:exnota/src/block/service/workspace_lister.dart';
import 'package:exnota/src/block/service/workspace_mutator.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_service.g.dart';

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

@riverpod
class WorkspaceService extends _$WorkspaceService {
  @override
  void build() {
    // no-op
  }

  Future<BasicResponse<void>> setIntegration(
      {required String workspaceId, required String integrationId}) async {
    final responseWrapper = ResponseWrapper<void>();
    return responseWrapper.wrapResponse(() async {
      return ref.read(workspaceMutatorProvider.notifier).setIntegration(
            workspaceId: workspaceId,
            integrationId: integrationId,
          );
    });
  }
}
