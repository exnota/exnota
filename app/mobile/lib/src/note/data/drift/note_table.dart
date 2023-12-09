import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_table.g.dart';

class NoteTable extends Table {
  @override
  String get tableName => 'note';

  TextColumn get id => text()();
  TextColumn get type => text().map(NoteTypeRepoConverter())();
  TextColumn get title => text().nullable()();
  TextColumn get captures => text().map(NoteCapturesRepoConverter())();
  TextColumn get localData => text().map(LocalDataRepo.converter)();
  TextColumn get integratedData => text().map(IntegratedDataRepo.converter)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Won't generate without alwaysCreate
@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum NoteTypeRepo {
  voice(dbName: "voice"),
  text(dbName: "text"),
  unknown(dbName: "unknown");

  const NoteTypeRepo({required this.dbName});

  final String dbName;
}

class NoteTypeRepoConverter extends TypeConverter<NoteTypeRepo, String> {
  @override
  NoteTypeRepo fromSql(String fromDb) =>
      _$NoteTypeRepoEnumMap.map((key, value) => MapEntry(value, key))[fromDb]!;

  @override
  String toSql(NoteTypeRepo value) => _$NoteTypeRepoEnumMap[value]!;
}

/// Stores the list of capture ids as a json array.
class NoteCapturesRepoConverter extends TypeConverter<List<String>, String> {
  @override
  List<String> fromSql(String fromDb) {
    final List<dynamic> decoded = jsonDecode(fromDb);
    return decoded.cast<String>();
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}

// Won't generate without alwaysCreate
@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum NoteLocalStatusRepo {
  capturing(dbName: "capturing"),
  captured(dbName: "captured"),
  synced(dbName: "synced");

  const NoteLocalStatusRepo({required this.dbName});

  final String dbName;

  factory NoteLocalStatusRepo.fromJson(String json) =>
      _$NoteLocalStatusRepoEnumMap
          .map((key, value) => MapEntry(value, key))[json]!;

  String toJson() => _$NoteLocalStatusRepoEnumMap[this]!;
}

/// Local data for all note types. Repo should convert to/from this to the
/// domain type.
@JsonSerializable(constructor: '_')
class LocalDataRepo {
  final NoteLocalStatusRepo status;

  LocalDataRepo._({required this.status});

  LocalDataRepo.voice({required this.status});

  LocalDataRepo.unknown({required this.status});

  factory LocalDataRepo.fromJson(Map<String, Object?> json) =>
      _$LocalDataRepoFromJson(json);

  Map<String, Object?> toJson() {
    return _$LocalDataRepoToJson(this);
  }

  static TypeConverter<LocalDataRepo, String> converter = TypeConverter.json(
    fromJson: (json) => LocalDataRepo.fromJson(json as Map<String, Object?>),
    toJson: (pref) => pref.toJson(),
  );
}

@JsonSerializable(constructor: '_')
class IntegratedDataRepo {
  final String? url;

  IntegratedDataRepo._({this.url});

  IntegratedDataRepo.voice({required this.url});

  IntegratedDataRepo.unknown({required this.url});

  factory IntegratedDataRepo.fromJson(Map<String, Object?> json) =>
      _$IntegratedDataRepoFromJson(json);

  Map<String, Object?> toJson() {
    return _$IntegratedDataRepoToJson(this);
  }

  static TypeConverter<IntegratedDataRepo, String> converter =
      TypeConverter.json(
    fromJson: (json) =>
        IntegratedDataRepo.fromJson(json as Map<String, Object?>),
    toJson: (pref) => pref.toJson(),
  );
}
