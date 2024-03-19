import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_runner.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncCommandHandler extends ConsumerStatefulWidget {
  final Widget child;

  const SyncCommandHandler({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<SyncCommandHandler> createState() => _SyncCommandHandlerState();
}

class _SyncCommandHandlerState extends ConsumerState<SyncCommandHandler> {
  static final Logger _log = Logger(context: 'SyncCommandHandler');

  late final SyncCommandRunner _runner;

  @override
  void initState() {
    super.initState();
    _runner = ref.read(syncCommandRunnerProvider);

    final connStatus = ref.read(connectionStatusProvider);
    _log.debug('Initial connection status: $connStatus');
    if (connStatus == ConnStatus.online) {
      _runner.start();
    }
  }

  @override
  void dispose() {
    _runner.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');
    ref.listen(connectionStatusProvider, (prevStatus, nextStatus) {
      _log.debug(
          'ConnectionStatus listener: Changed from $prevStatus -> $nextStatus');
      if (nextStatus == ConnStatus.online) {
        _runner.start();
      } else {
        _runner.stop();
      }
    });
    return widget.child;
  }
}
