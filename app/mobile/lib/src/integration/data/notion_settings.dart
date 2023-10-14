import 'package:drift/drift.dart';

class IntegrationNotionSettings extends Table {
  @override
  String get tableName => 'integration_notion_settings';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().nullable().withLength(min: 1)();
  TextColumn get accessToken => text().nullable().withLength(min: 1)();
}
