import 'package:exnota/src/block/repo/drift/workspace_repo.dart';
import 'package:exnota/src/block/workspace.dart';
import 'package:exnota/src/lib/log/logger.dart';
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

  // Does not catch errors
  Future<void> import(RecordModel? record) async {
    if (record == null) {
      _log.warn('No workspace record to import');
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

  Future<void> importAll(List<RecordModel> records) async {
    _log.debug('Importing ${records.length} workspace records');

    // Don't use a transaction. We don't want one failed import to block the
    // rest.
    for (final record in records) {
      await import(record);
    }
  }
}
