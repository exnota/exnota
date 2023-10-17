import 'package:Exnota/src/integration/data/notion_settings_repo.dart';
import 'package:Exnota/src/integration/notion_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notion_settings_service.g.dart';

@riverpod
Future<NotionSettings> notionSettingsService(
    NotionSettingsServiceRef ref) async {
  return ref.watch(notionSettingsRepoProvider.future);
}
