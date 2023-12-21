import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'local_file_table.g.dart';

class LocalFileTable extends Table {
  @override
  String get tableName => 'local_file';

  TextColumn get id => text()();
  TextColumn get entityType => text().map(EntityTypeRepoConverter())();
  TextColumn get entityId => text()();
  TextColumn get path => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum EntityTypeRepo {
  block(dbName: "block");

  const EntityTypeRepo({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}

class EntityTypeRepoConverter extends TypeConverter<EntityTypeRepo, String> {
  @override
  EntityTypeRepo fromSql(String fromDb) => _$EntityTypeRepoEnumMap
      .map((key, value) => MapEntry(value, key))[fromDb]!;

  @override
  String toSql(EntityTypeRepo value) => _$EntityTypeRepoEnumMap[value]!;
}
