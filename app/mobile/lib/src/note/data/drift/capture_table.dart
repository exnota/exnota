import 'package:drift/drift.dart';

// Enum names are used in the database. So don't rename without handling the
// migration.
enum CaptureTableType { audio }

class CaptureTable extends Table {
  @override
  String get tableName => 'capture';

  TextColumn get id => text()();
  TextColumn get type => textEnum<CaptureTableType>()();

  @override
  Set<Column> get primaryKey => {id};
}
