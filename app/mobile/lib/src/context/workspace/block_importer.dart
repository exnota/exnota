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

  Future<void> import(RecordModel? record) async {
    if (record == null) {
      _log.warn('No block record to import');
      return;
    }

    final repo = ref.read(blockRepoProvider);
    try {
      _log.debug('Mapping block record ${record.id}');
      final block = Block.fromRecord(record);

      _log.debug('Upserting block ${block.id}');
      await repo.upsert(block);
    } catch (e) {
      _log.error('Error importing block ${record.id}', exception: e);
    }
    _log.debug('Imported block ${record.id}');
  }

  Future<void> importAll(List<RecordModel> records) async {
    _log.debug('Importing ${records.length} block records');

    // Don't use a transaction. We don't want one failed import to block the
    // rest.
    for (final record in records) {
      await import(record);
    }
  }
}
