import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_importer.g.dart';

@riverpod
BlockImporter blockImporter(BlockImporterRef ref) {
  final pb = ref.watch(pocketBaseProvider);
  final importer = BlockImporter(pb: pb);
  return importer;
}

class BlockImporter {
  final Logger _log = Logger(context: 'BlockImporter');
  final PocketBase pb;
  Future<void> Function()? _unsub;

  BlockImporter({required this.pb});

  Future<void> subscribe() async {
    _log.info('Subscribing to block collection');
    _unsub = await pb.collection('block').subscribe("*", (e) {
      switch (e.action) {
        case 'create':
          // TODO: Call block creation service
          _log.info('Block created: ${e.record}');
          break;
        case 'update':
          // TODO: Call block update service
          _log.info('Block updated: ${e.record}');
          break;
        case 'delete':
          // This shouldn't happen
          _log.warn("Block deleted", nonPrivateData: {
            "id": e.record?.id,
          });
          break;
      }
    });
  }

  void unsubscribe() {
    _log.info('Unsubscribing from block collection');
    _unsub?.call();
  }
}
