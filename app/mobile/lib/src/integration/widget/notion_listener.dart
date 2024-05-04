import 'dart:async';

import 'package:exnota/src/common/device/app_links.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notion_listener.g.dart';
part 'notion_listener.freezed.dart';

@freezed
class NotionAuthState with _$NotionAuthState {
  const factory NotionAuthState({
    required bool waitingForCode,
    required String? integrationId,
    required String? code,
  }) = _NotionAuthState;
}

@Riverpod(keepAlive: true)
class NotionAuth extends _$NotionAuth {
  final Logger _log = Logger(context: 'NotionAuth');

  @override
  NotionAuthState build() {
    return const NotionAuthState(
      waitingForCode: false,
      integrationId: null,
      code: null,
    );
  }

  void saveCode({required String code}) {
    _log.debug('Saving code: $code');
    state = state.copyWith(code: code);
  }
}

class NotionListener extends ConsumerStatefulWidget {
  final Widget child;

  const NotionListener({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<NotionListener> createState() => _NotionListenerState();
}

class _NotionListenerState extends ConsumerState<NotionListener> {
  static final Logger _log = Logger(context: 'NotionListener');

  late final StreamSubscription<Uri> _listener;

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
    final appLinks = ref.read(appLinksProvider);
    appLinks.getInitialAppLink().then((uri) {
      _log.debug('Initial link: $uri');
      if (uri != null) {
        // TODO: Check that the rest of the uri matches too (i.e. it's not some
        // other code)
        final code = uri.queryParameters['code'];
        if (code != null) {
          _log.debug('Link with code received');
          ref.read(notionAuthProvider.notifier).saveCode(code: code);
        }
      }
    });

    _listener = appLinks.uriLinkStream.listen((uri) {
      _log.debug('Link: $uri');
      // TODO: Check that the rest of the uri matches too (i.e. it's not some
      // other code)
      final code = uri.queryParameters['code'];
      if (code != null) {
        _log.debug('Link with code received');
        ref.read(notionAuthProvider.notifier).saveCode(code: code);
      }
    });
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    _listener.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');
    return widget.child;
  }
}
