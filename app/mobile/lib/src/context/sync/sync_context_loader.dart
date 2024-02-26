import 'package:exnota/src/context/sync/import_queue.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncContextLoader extends ConsumerStatefulWidget {
  final Widget child;

  const SyncContextLoader({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<SyncContextLoader> createState() => _SyncContextLoaderState();
}

class _SyncContextLoaderState extends ConsumerState<SyncContextLoader> {
  final _log = Logger(context: 'SyncContextLoader');

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');
    return ImportQueueProcessor(child: widget.child);
  }
}
