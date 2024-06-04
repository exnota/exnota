import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/block.dart';
import 'package:exnota/src/block/repo/drift/block_repo.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_importer.g.dart';

@riverpod
class BlockImporter extends _$BlockImporter {
  final _log = Logger(context: 'BlockImporter');

  @override
  FutureOr<void> build() {
    // No-op
  }

  Future<void> import({required Block block}) async {
    final repo = ref.read(blockRepoProvider);
    try {
      _log.debug('Upserting block ${block.id}');
      await repo.upsert(block);
    } catch (e) {
      _log.error('Error importing block ${block.id}', exception: e);
    }
  }

  Future<void> importRecord(RecordModel? record) async {
    if (record == null) {
      _log.warn('No block record to import');
      return;
    }

    try {
      final block = Block.fromRecord(record);

      return import(block: block);
    } catch (e) {
      _log.error('Error mapping block record ${record.id}', exception: e);
    }
  }

  Future<void> importAllRecords(List<RecordModel> records) async {
    _log.debug('Importing ${records.length} block records');

    // Don't use a transaction. We don't want one failed import to block the
    // rest.
    for (final record in records) {
      await importRecord(record);
    }
  }
}
