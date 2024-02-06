import 'package:drift/drift.dart';

// Keep this as a subset of the server-side model for keeping the sync logic
// simple. Any additional, local-only fields should be added to another table.
class UserTable extends Table {
  @override
  String get tableName => 'user';

  TextColumn get id => text()();
  TextColumn get email => text()();
  BoolColumn get verified => boolean()();
  DateTimeColumn get created => dateTime().nullable()();
  DateTimeColumn get updated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
