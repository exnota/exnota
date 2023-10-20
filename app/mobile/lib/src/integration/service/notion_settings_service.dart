import 'dart:convert';

import 'package:exnota/src/integration/data/notion_settings_repo.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'notion_settings_service.g.dart';

@riverpod
class NotionSettingsService extends _$NotionSettingsService {
  @override
  Future<NotionSettings> build() async {
    return ref.watch(notionSettingsRepoProvider.future);
  }

  Future<void> saveCode(String code) async {
    final settings = NotionSettings.code(code: code);
    await ref
        .read(notionSettingsRepoProvider.notifier)
        .updateSettings(settings);
    ref.invalidateSelf();
    // Re-read provider to avoid this error briefly being returned:
    // https://github.com/rrousselGit/riverpod/issues/2041#issuecomment-1698884238
    ref.read(notionSettingsRepoProvider.notifier);
  }

  Future<bool> fetchToken() async {
    final currentSettings = state.valueOrNull;
    switch (currentSettings) {
      case NotionSettingsCode():
        final code = currentSettings.code;
        final response = await http.post(
          Uri.https('exnota.com', 'api/notion-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"code": code}),
        );
        // 201 expected, but also accept 200 in case they change things.
        if (![200, 201].contains(response.statusCode)) {
          return false;
        }
        final body = jsonDecode(response.body);
        final accessToken = body["access_token"];
        final newSettings =
            NotionSettings.accessToken(accessToken: accessToken);
        await ref
            .read(notionSettingsRepoProvider.notifier)
            .updateSettings(newSettings);
        ref.invalidateSelf();
        // Re-read provider to avoid this error briefly being returned:
        // https://github.com/rrousselGit/riverpod/issues/2041#issuecomment-1698884238
        ref.read(notionSettingsRepoProvider.notifier);
        return true;
      default:
        return false;
    }
  }
}
