import 'package:drift/drift.dart';

// Keep this as a subset of the server-side model for keeping the sync logic
// simple. Any additional, local-only fields should be added to another table.
class WorkspaceTable extends Table {
  @override
  String get tableName => 'workspace';

  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  // Allow any value in case of future expansion
  TextColumn get type => text()();

  TextColumn get integration => text().nullable()();

  // Allow any value in case of future expansion
  TextColumn get external => text().nullable()();

  // User id. Don't use foreign key to user table because the user may not be
  // synced (and for now we only expect 1 user).
  TextColumn get user => text()();

  // created and updated are server-generated. Leave empty and wait to fetch
  // them from the server.
  DateTimeColumn get created => dateTime().nullable()();
  DateTimeColumn get updated => dateTime().nullable()();
  DateTimeColumn get archived => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
