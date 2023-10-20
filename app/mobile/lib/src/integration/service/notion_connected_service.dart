import 'package:exnota/src/integration/notion_settings.dart';
import 'package:exnota/src/integration/service/notion_settings_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notion_connected_service.g.dart';

/// Returns true if notion has been connected.
@riverpod
bool notionConnectedService(NotionConnectedServiceRef ref) {
  final settings = ref.watch(notionSettingsServiceProvider).valueOrNull;
  switch (settings) {
    case NotionSettingsAccessToken():
      return true;
    default:
      return false;
  }
}
