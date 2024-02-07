import 'package:exnota/src/account/user/service/user_context_service.dart';
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
      print(e.action); // create, update, delete
      print(e.record); // the changed record
    });
  }

  void unsubscribe() {
    _log.info('Unsubscribing from block collection');
    _unsub?.call();
  }
}
