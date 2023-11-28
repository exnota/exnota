import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/integration/notion_settings.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notion_settings_repo.g.dart';

@Riverpod(keepAlive: true)
class NotionSettingsRepo extends _$NotionSettingsRepo {
  @override
  Future<NotionSettings> build() async {
    final db = ref.watch(databaseProvider);
    final settings = await db.select(db.integrationNotionSettings).get();
    if (settings.isEmpty) {
      return const NotionSettings.empty();
    }
    final setting = settings[0];
    final accessToken = setting.accessToken;
    if (accessToken != null) {
      return NotionSettings.accessToken(accessToken: accessToken);
    }
    final code = setting.code;
    if (code != null) {
      return NotionSettings.code(code: code);
    }
    return const NotionSettings.empty();
  }

  Future<void> updateSettings(NotionSettings newSettings) async {
    final db = ref.watch(databaseProvider);
    final existingAll = await db.select(db.integrationNotionSettings).get();

    // If settings don't exist in DB -> Insert if not empty
    if (existingAll.isEmpty) {
      switch (newSettings) {
        case NotionSettingsCode():
        case NotionSettingsAccessToken():
          final mapped = _mapToCompanion(newSettings, null);
          await db.into(db.integrationNotionSettings).insert(mapped);
          ref.invalidateSelf();
          break;
        case NotionSettingsEmpty():
          break;
      }
      return;
    }

    // If new settings are empty, delete. Otherwise update.
    final existingSettings = existingAll[0];
    switch (newSettings) {
      case NotionSettingsEmpty():
        await db.delete(db.integrationNotionSettings).delete(existingSettings);
        break;
      case NotionSettingsCode():
      case NotionSettingsAccessToken():
        final replacement = _mapToCompanion(newSettings, existingSettings.id);
        await db.update(db.integrationNotionSettings).replace(replacement);
        break;
    }
    ref.invalidateSelf();
  }

  IntegrationNotionSettingsCompanion _mapToCompanion(
      NotionSettings settings, int? id) {
    IntegrationNotionSettingsCompanion mapped;
    switch (settings) {
      case NotionSettingsEmpty():
        throw Exception('Can\'t map empty Notion settings');
      case NotionSettingsCode():
        mapped = IntegrationNotionSettingsCompanion(
            code: Value(settings.code),
            // Using Value.absent() here doesn't override existing value
            accessToken: const Value(null),
            id: id != null ? Value(id) : const Value.absent());
        break;
      case NotionSettingsAccessToken():
        mapped = IntegrationNotionSettingsCompanion(
            accessToken: Value(settings.accessToken),
            // Using Value.absent() here doesn't override existing value
            code: const Value(null),
            id: id != null ? Value(id) : const Value.absent());
        break;
    }
    return mapped;
  }
}
