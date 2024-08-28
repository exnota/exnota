import 'package:exnota/src/block/repo/drift/workspace_importer.dart';
import 'package:exnota/src/block/repo/drift/workspace_repo.dart';
import 'package:exnota/src/block/service/workspace_lister.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_exporter.g.dart';

@riverpod
class WorkspaceExporter extends _$WorkspaceExporter {
  final _log = Logger(context: 'WorkspaceExporter');

  @override
  FutureOr<void> build() {
    // No-op
  }

  Future<BasicResponse<Workspace>> create(
      {required WorkspaceType type, required String integrationId}) async {
    _log.debug('export: Creating workspace');

    // Create workspace
    final userId = ref.watch(activeUserIdOrThrowSyncProvider);
    final request = CreateWorkspaceRequest(
        type: type, integrationId: integrationId, userId: userId);
    final result =
        await ref.read(requestHandlerProvider.notifier).submitWrapped(
              request: request,
            );

    // Import to database
    switch (result) {
      case BasicResponseSuccess(:final result):
        _log.debug('export: Export successful');
        final workspace = await ref
            .read(workspaceImporterProvider.notifier)
            .importRecord(result);
        return BasicResponse.success(result: workspace);
      case BasicResponseError(:final error, :final errorCode):
        _log.error('export: Export failed');
        return BasicResponse.error(error: error, errorCode: errorCode);
    }
  }

  // Does not catch errors
  Future<void> _export(RecordModel? record) async {
    if (record == null) {
      _log.warn('No workspace record to export');
      return;
    }

    final repo = ref.read(workspaceRepoProvider);
    try {
      final workspace = Workspace.fromRecord(record);

      _log.debug('Upserting workspace ${workspace.id}');
      await repo.upsert(workspace);
    } catch (e) {
      _log.error('Error importing workspace ${record.id}', exception: e);
      rethrow;
    }
  }

  Future<void> _importAll(List<RecordModel> records) async {
    _log.debug('Importing ${records.length} workspace records');

    // Don't use a transaction. We don't want one failed import to block the
    // rest.
    for (final record in records) {
      // await _import(record);
    }
  }
}

class CreateWorkspaceRequest extends HandledRequest<RecordModel> {
  final Logger _log = Logger(context: 'CreateWorkspaceRequest');

  final WorkspaceType type;
  final String integrationId;
  final String userId;

  CreateWorkspaceRequest(
      {required this.type, required this.integrationId, required this.userId});

  @override
  Future<RecordModel> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Creating workspace');
    final body = Workspace.createRequestBodyWithoutId(
        type: type, integrationId: integrationId, userId: userId);
    final response =
        await pb.collection(collectionWorkspace).create(body: body);
    _log.debug('request: Created workspace ${response.id}');

    return response;
  }
}
