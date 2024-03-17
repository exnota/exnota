import 'package:drift/drift.dart';

class SyncCommandTable extends Table {
  @override
  String get tableName => 'sync_command';

  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get entityId => text()();
  TextColumn get rootEntityId => text()();
  TextColumn get userId => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {id};
}
