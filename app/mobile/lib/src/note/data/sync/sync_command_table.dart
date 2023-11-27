import 'package:drift/drift.dart';

// Enum names are used in the database. So don't rename without handling the
// migration.
enum SyncCommandRepoType { createAudioNote }

// Enum names are used in the database. So don't rename without handling the
// migration.
enum SyncCommandRepoStatus {
  waiting,
  running,
  complete,
}

// TODO: Add created date and updated date
class SyncCommandTable extends Table {
  @override
  String get tableName => 'sync_command';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<SyncCommandRepoType>()();
  TextColumn get entityId => text()();
  TextColumn get status => textEnum<SyncCommandRepoStatus>()();
  TextColumn get data => text()();
}
