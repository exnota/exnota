import 'package:drift/drift.dart';

class LocalFileTable extends Table {
  @override
  String get tableName => 'local_file';

  TextColumn get id => text()();
  TextColumn get fileType => text()();
  TextColumn get status => text()();
  TextColumn get path => text().unique()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  DateTimeColumn get created => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
