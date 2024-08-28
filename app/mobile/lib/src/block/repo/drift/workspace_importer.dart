import 'package:exnota/src/block/repo/drift/workspace_repo.dart';
import 'package:exnota/src/block/service/workspace_lister.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/context/sync/request_handler.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/common/basic_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_importer.g.dart';

@riverpod
class WorkspaceImporter extends _$WorkspaceImporter {
  final _log = Logger(context: 'WorkspaceImporter');

  @override
  FutureOr<void> build() {
    // No-op
  }

  // Does not return workspace(s) because there could be multiple and the lister
  // is the service that should determine which one to return.
  Future<BasicResponse<void>> import() async {
    _log.debug('import: Importing workspaces');

    // Request workspaces
    final request = WorkspaceImportRequest();
    final result =
        await ref.read(requestHandlerProvider.notifier).submitWrapped(
              request: request,
            );

    // Import to database
    switch (result) {
      case BasicResponseSuccess():
        _log.debug('import: Import successful');
        await _importAll(result.result);
        ref.read(workspaceListerProvider.notifier).refresh();
        return const BasicResponse.success(result: null);
      case BasicResponseError():
        _log.error('import: Import failed');
        ref.read(workspaceListerProvider.notifier).refresh();
        return result;
    }
  }

  // Does not catch errors
  Future<Workspace> importRecord(RecordModel record) async {
    final repo = ref.read(workspaceRepoProvider);
    try {
      final workspace = Workspace.fromRecord(record);

      _log.debug('Upserting workspace ${workspace.id}');
      await repo.upsert(workspace);
      return workspace;
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
      await importRecord(record);
    }
  }
}

class WorkspaceImportRequest extends HandledRequest<List<RecordModel>> {
  final Logger _log = Logger(context: 'WorkspaceImportRequest');

  @override
  Future<List<RecordModel>> request(
      {required PocketBase pb, required Ref ref}) async {
    _log.debug('request: Importing workspace records');

    // This deliberately includes archived workspaces so they can be updated in
    // the local databse.
    return await pb.collection(collectionWorkspace).getFullList();
  }
}

