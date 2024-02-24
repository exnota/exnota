import 'package:exnota/src/context/workspace/block_import_fetcher.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkspaceContextLoader extends ConsumerStatefulWidget {
  final Widget child;

  const WorkspaceContextLoader({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<WorkspaceContextLoader> createState() =>
      _WorkspaceContextLoaderState();
}

class _WorkspaceContextLoaderState
    extends ConsumerState<WorkspaceContextLoader> {
  final Logger _log = Logger(context: 'WorkspaceContextLoader');

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
    return BlockImportFetcher(child: widget.child);
  }
}
