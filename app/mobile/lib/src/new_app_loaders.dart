import 'package:exnota/src/integration/widget/notion_listener.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Eventually this should be split into loaders for each domain and replace
// the 'contexts' as currently in app.dart.
//
// See architecture.md for more details.
class NewAppLoaders extends ConsumerStatefulWidget {
  final Widget child;

  const NewAppLoaders({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<NewAppLoaders> createState() => _NewAppLoadersState();
}

class _NewAppLoadersState extends ConsumerState<NewAppLoaders> {
  final _log = Logger(context: 'NewAppLoaders');

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
    return NotionListener(child: widget.child);
  }
}
