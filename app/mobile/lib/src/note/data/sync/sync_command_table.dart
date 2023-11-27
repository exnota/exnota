import 'package:drift/drift.dart';

enum SyncCommandType { createAudioNote }

class SyncCommandTable extends Table {
  @override
  String get tableName => 'sync_command';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<SyncCommandType>()();
  TextColumn get entityId => text()();
  TextColumn get data => text()();
}
