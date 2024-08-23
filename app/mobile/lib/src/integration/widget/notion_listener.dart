// ignore_for_file: invalid_annotation_target

import 'dart:async';
import 'dart:convert';

import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/secure/secure_storage.dart';
import 'package:exnota/src/common/device/app_links.dart';
import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notion_listener.g.dart';
part 'notion_listener.freezed.dart';

/// Data persisted to secure storage. This contains more data than the provider
/// state, so consumers can use a simpler state object.
///
/// Keeps a copy of the last code saved because `appLinks.getInitialAppLink()`,
/// at least when debugging locally, does not clear initial app links once they
/// have been consumed. This results in the same Notion auth code being detected
/// multiple times, e.g. after a hot reload, and causes an attempt at updating
/// the integration with the previous code, causing an error.
@freezed
class _NotionAuthStatePersisted with _$NotionAuthStatePersisted {
  const factory _NotionAuthStatePersisted({
    @JsonKey(name: 'code') required String? code,
    @JsonKey(name: 'firstSaved') required DateTime? firstSaved,
    @JsonKey(name: 'usedOrInvalid') required bool usedOrInvalid,
  }) = __NotionAuthStatePersisted;

  factory _NotionAuthStatePersisted.fromJson(Map<String, dynamic> json) =>
      _$NotionAuthStatePersistedFromJson(json);
}

/// [code] is not returned if it has been cleared.
@freezed
class NotionAuthState with _$NotionAuthState {
  const NotionAuthState._();

  const factory NotionAuthState({
    required String? code,
    required DateTime? firstSaved,
  }) = _NotionAuthState;

  bool hasPassedExpiry() {
    return firstSaved != null &&
        Clock().now().difference(firstSaved!) > const Duration(minutes: 5);
  }

  factory NotionAuthState.fromJson(Map<String, dynamic> json) =>
      _$NotionAuthStateFromJson(json);
}

@Riverpod(keepAlive: true)
class NotionAuth extends _$NotionAuth {
  final Logger _log = Logger(context: 'NotionAuth');
  int _listenerCount = 0;

  @override
  Future<NotionAuthState> build() async {
    _log.debug('Building');

    ref.onAddListener(() {
      _log.debug('Listener added');
      _listenerCount++;
    });
    ref.onRemoveListener(() {
      _log.debug('Listener removed');
      _listenerCount--;
    });

    final persisted = await _getPersisted();
    return _stateFromPersisted(persisted);
  }

  Future<_NotionAuthStatePersisted?> _getPersisted() async {
    final storage = SecureStorage();
    final json = await storage.read(key: SecureStorageKey.notionAuthCode);
    if (json != null) {
      return _NotionAuthStatePersisted.fromJson(jsonDecode(json));
    }
    return null;
  }

  Future<void> _setPersisted(_NotionAuthStatePersisted persisted) async {
    final storage = SecureStorage();
    await storage.write(
        key: SecureStorageKey.notionAuthCode,
        value: jsonEncode(persisted.toJson()));
  }

  NotionAuthState _stateFromPersisted(_NotionAuthStatePersisted? persisted) {
    if (persisted == null) {
      return const NotionAuthState(code: null, firstSaved: null);
    }

    if (persisted.usedOrInvalid) {
      return const NotionAuthState(code: null, firstSaved: null);
    }

    return NotionAuthState(
      code: persisted.code,
      firstSaved: persisted.firstSaved,
    );
  }

  void saveCode({required String code}) async {
    _log.debug('Saving code');

    final persisted = await _getPersisted();
    if (persisted != null && persisted.code == code) {
      _log.debug('Code is the same as last saved, not updating');
      return;
    }

    final updatedPersisted = _NotionAuthStatePersisted(
      code: code,
      firstSaved: Clock().now(),
      usedOrInvalid: false,
    );
    final updatedState = _stateFromPersisted(updatedPersisted);

    await _setPersisted(updatedPersisted);
    state = AsyncData(updatedState);

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

  Future<void> clearCode() async {
    _log.debug('Clearing code');
    final persisted = await _getPersisted();
    if (persisted == null) {
      _log.debug('No code to clear');
      return;
    }

    final updatedPersisted = persisted.copyWith(usedOrInvalid: true);
    final updatedState = _stateFromPersisted(updatedPersisted);

    await _setPersisted(updatedPersisted);
    state = AsyncData(updatedState);
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
