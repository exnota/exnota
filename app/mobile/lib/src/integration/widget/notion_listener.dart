import 'dart:async';

import 'package:exnota/src/common/device/app_links.dart';
import 'package:exnota/src/context/app/router.dart';
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
    required String? code,
  }) = _NotionAuthState;
}

@Riverpod(keepAlive: true)
class NotionAuth extends _$NotionAuth {
  final Logger _log = Logger(context: 'NotionAuth');
  int _listenerCount = 0;

  @override
  NotionAuthState build() {
    _log.debug('Building');

    ref.onAddListener(() {
      _log.debug('Listener added');
      _listenerCount++;
    });
    ref.onRemoveListener(() {
      _log.debug('Listener removed');
      _listenerCount--;
    });

    return const NotionAuthState(
      code: null,
    );
  }

  void saveCode({required String code}) {
    _log.debug('Saving code: $code');
    state = state.copyWith(code: code);

    if (_listenerCount == 0) {
      // If Setup Integration Screen is open, which is the standard user flow,
      // it will be listening for the code. But if the user has navigated
      // elsewhere in Exnota or the app has been closed, we need to navigate
      // to the setup screen so the code can be exchanged for a token.
      _log.debug('No listeners, pushing to setup integration screen');
      ref
          .read(initializeOrPushscreenProvider.notifier)
          .initOrPush(Screen.settingsSetupIntegration);
    }
  }

  void clearCode() {
    _log.debug('Clearing code');
    state = state.copyWith(code: null);
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
        // Don't check the path, because we get the path from the backend. It
        // could be updated at any point.
        final code = uri.queryParameters['code'];
        if (code != null) {
          _log.debug('Link with code received');
          ref.read(notionAuthProvider.notifier).saveCode(code: code);
        }
      }
    });

    _listener = appLinks.uriLinkStream.listen((uri) {
      _log.debug('Link: $uri');
      // Don't check the path, because we get the path from the backend. It
      // could be updated at any point.
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
