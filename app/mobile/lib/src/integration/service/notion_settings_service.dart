import 'dart:convert';

import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/integration/repo/notion_settings_repo.dart';
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
        // Token for a given user doesn't seem to change, even if the pages they have
        // given access to change. Though a new code is generated each time. Not sure
        // then if we need to send the new code to this endpoint.
        //
        // Lint error below looks like a false positive, as uriServiceLegacyProvider
        // is not a manual provider. Copied the "family" provider implementation
        // as per: https://codewithandrea.com/articles/flutter-riverpod-generator/
        // ignore: avoid_manual_providers_as_generated_provider_dependency
        final uri = ref.read(uriServiceLegacyProvider(path: 'notion-token'));
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"code": code}),
        );
        // 201 expected, but also accept 200 in case they change things.
        if (![200, 201].contains(response.statusCode)) {
          return false;
        }
        final body = jsonDecode(response.body);
        final accessToken = body["access_token"];
        final workspaceId = body["workspace_id"] as String?;
        final botId = body["bot_id"] as String?;
        final owner = body["owner"] as Map<String, dynamic>?;
        final ownerUser =
            owner != null ? owner["user"] as Map<String, dynamic>? : null;
        final ownerUserId =
            ownerUser != null ? ownerUser["id"] as String? : null;

        final newSettings = NotionSettings.accessToken(
            accessToken: accessToken,
            botId: botId,
            workspaceId: workspaceId,
            ownerUserId: ownerUserId);
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

  Future<void> setTokenForPlayConsoleTesting(String secret) async {
    final settings = NotionSettings.accessToken(accessToken: secret);
    await ref
        .read(notionSettingsRepoProvider.notifier)
        .updateSettings(settings);
    ref.invalidateSelf();
    // Re-read provider to avoid this error briefly being returned:
    // https://github.com/rrousselGit/riverpod/issues/2041#issuecomment-1698884238
    ref.read(notionSettingsRepoProvider.notifier);
  }
}
