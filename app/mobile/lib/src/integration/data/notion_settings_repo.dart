import 'package:Exnota/database.dart';
import 'package:Exnota/src/integration/notion_settings.dart';
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
}
