import 'package:drift/drift.dart';

class NotionSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().nullable().withLength(min: 1)();
}
