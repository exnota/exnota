import 'package:drift/drift.dart';

// Keep this as a subset of the server-side model for keeping the sync logic
// simple. Any additional, local-only fields should be added to another table.
class BlockTable extends Table {
  @override
  String get tableName => 'block';

  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  // Allow any value in case of future expansion
  TextColumn get type => text()();

  TextColumn get externalUrl => text().nullable()();

  // Filename, generated server-side. Path can be generated from the filename,
  // collection and file system.
  TextColumn get file => text().nullable()();
  // Allow any value in case of future expansion
  TextColumn get audio => text().nullable()();

  // User id. Don't use foreign key to user table because the user may not be
  // synced (and for now we only expect 1 user).
  TextColumn get user => text()();
  DateTimeColumn get userCreated => dateTime()();
  // created and updated are server-generated. Leave empty and wait to fetch
  // them from the server.
  DateTimeColumn get created => dateTime().nullable()();
  DateTimeColumn get updated => dateTime().nullable()();
  DateTimeColumn get archived => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
