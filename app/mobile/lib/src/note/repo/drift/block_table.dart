import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'block_table.g.dart';

class BlockTable extends Table {
  @override
  String get tableName => 'block';

  TextColumn get id => text()();
  TextColumn get type => text().map(BlockTypeRepoConverter())();
  TextColumn get properties => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastEditedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum BlockTypeRepo {
  audio(dbName: "audio");

  const BlockTypeRepo({required this.dbName});

  final String dbName;
}

class BlockTypeRepoConverter extends TypeConverter<BlockTypeRepo, String> {
  @override
  BlockTypeRepo fromSql(String fromDb) =>
      _$BlockTypeRepoEnumMap.map((key, value) => MapEntry(value, key))[fromDb]!;

  @override
  String toSql(BlockTypeRepo value) => _$BlockTypeRepoEnumMap[value]!;
}
