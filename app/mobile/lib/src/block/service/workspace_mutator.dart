import 'dart:async';

import 'package:exnota/src/block/repo/drift/workspace_importer.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_mutator.g.dart';

@riverpod
class WorkspaceMutator extends _$WorkspaceMutator {
  final _log = Logger(context: 'WorkspaceMutator');

  @override
  void build() {
    // no-op
  }

  Future<void> setIntegration(
      {required String workspaceId, required String integrationId}) async {
    final completor = Completer<void>();
    final request = WorkspaceSetIntegrationRequest(
      workspaceId: workspaceId,
      integrationId: integrationId,
    );
    unawaited(ref.read(requestHandlerProvider.notifier).submit(
          request: request,
          onSuccess: (_) {
            _log.debug(
                'setIntegration: Successfully set integration for workspace');
            completor.complete();
          },
          onError: (error) {
            _log.error('setIntegration: Set integration errored',
                exception: error);
            completor.completeError(error);
          },
        ));

    return completor.future;
  }
}

class WorkspaceSetIntegrationRequest extends HandledRequest<void> {
  final Logger _log = Logger(context: 'WorkspaceSetIntegrationRequest');

  late final String workspaceId;
  late final String integrationId;

  WorkspaceSetIntegrationRequest(
      {required this.workspaceId, required this.integrationId});

  @override
  Future<void> request({required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Setting integration for workspace');

    final updatedRecord = await pb.collection(collectionWorkspace).update(
      workspaceId,
      body: {workspaceFieldIntegration: integrationId},
    );

    _log.debug('request: Importing updated workspace record');
    await ref.read(workspaceImporterProvider.notifier).import(updatedRecord);

    return;
  }
}
