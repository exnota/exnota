import 'package:drift/drift.dart';

// Keep this as a subset of the server-side model for keeping the sync logic
// simple. Any additional, local-only fields should be added to another table.
class DestinationTable extends Table {
  @override
  String get tableName => 'destination';

  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  TextColumn get workspace => text()();

  // Allow any value in case of future expansion
  TextColumn get external => text().nullable()();

  // User id. Don't use foreign key to user table because the user may not be
  // synced (and for now we only expect 1 user).
  TextColumn get user => text()();

  DateTimeColumn get created => dateTime().nullable()();
  DateTimeColumn get updated => dateTime().nullable()();
  DateTimeColumn get archived => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
