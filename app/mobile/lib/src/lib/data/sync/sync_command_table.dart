import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sync_command_table.g.dart';

// TODO: Add created date and updated date
class SyncCommandTable extends Table {
  @override
  String get tableName => 'sync_command';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text().map(SyncCommandRepoTypeConverter())();
  TextColumn get entityId => text()();
  TextColumn get status => text().map(SyncCommandRepoStatusConverter())();
  TextColumn get data => text()();
}

// Won't generate without alwaysCreate
@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum SyncCommandRepoType {
  createAudioNote(dbName: 'createAudioNote');

  const SyncCommandRepoType({required this.dbName});

  final String dbName;
}

class SyncCommandRepoTypeConverter
    extends TypeConverter<SyncCommandRepoType, String> {
  @override
  SyncCommandRepoType fromSql(String fromDb) => _$SyncCommandRepoTypeEnumMap
      .map((key, value) => MapEntry(value, key))[fromDb]!;

  @override
  String toSql(SyncCommandRepoType value) =>
      _$SyncCommandRepoTypeEnumMap[value]!;
}

// Won't generate without alwaysCreate
@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum SyncCommandRepoStatus {
  waiting(dbName: 'waiting'),
  running(dbName: 'running'),
  complete(dbName: 'complete'),
  error(dbName: 'error');

  const SyncCommandRepoStatus({required this.dbName});

  final String dbName;
}

class SyncCommandRepoStatusConverter
    extends TypeConverter<SyncCommandRepoStatus, String> {
  @override
  SyncCommandRepoStatus fromSql(String fromDb) => _$SyncCommandRepoStatusEnumMap
      .map((key, value) => MapEntry(value, key))[fromDb]!;

  @override
  String toSql(SyncCommandRepoStatus value) =>
      _$SyncCommandRepoStatusEnumMap[value]!;
}
