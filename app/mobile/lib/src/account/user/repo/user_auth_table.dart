import 'package:drift/drift.dart';
import 'package:exnota/src/account/user/repo/user_table.dart';

// Contains local auth state.
class UserAuthTable extends Table {
  @override
  String get tableName => 'user_auth';

  TextColumn get id => text()();
  TextColumn get userId => text().references(UserTable, #id).unique()();
  TextColumn get token => text().nullable()();
  BoolColumn get active => boolean()();
  BoolColumn get valid => boolean()();
  DateTimeColumn get created => dateTime()();
  DateTimeColumn get updated => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
