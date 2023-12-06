import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_table.g.dart';

class NoteTable extends Table {
  @override
  String get tableName => 'note';

  TextColumn get id => text()();
  TextColumn get type => textEnum<NoteTableType>()();
  TextColumn get title => text().nullable()();
  TextColumn get captures => text().map(NoteTableCapturesConverter())();
  TextColumn get localData => text().map(LocalDataAll.converter)();
  TextColumn get integratedData => text().map(IntegratedDataRepo.converter)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

enum NoteTableType {
  voice(jsonName: "voice"),
  text(jsonName: "text"),
  unknown(jsonName: "unknown");

  const NoteTableType({required this.jsonName});

  final String jsonName;
}

/// Stores the list of capture ids as a json array.
class NoteTableCapturesConverter extends TypeConverter<List<String>, String> {
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

// Don't rename without migration.
enum NoteLocalStatusRepo { capturing, captured, synced }

/// Local data for all note types. Repo should convert to/from this to the
/// domain type.
@JsonSerializable(constructor: '_')
class LocalDataAll {
  final NoteLocalStatusRepo status;

  LocalDataAll._({required this.status});

  LocalDataAll.voice({required this.status});

  LocalDataAll.unknown({required this.status});

  factory LocalDataAll.fromJson(Map<String, Object?> json) =>
      _$LocalDataAllFromJson(json);

  Map<String, Object?> toJson() {
    return _$LocalDataAllToJson(this);
  }

  static TypeConverter<LocalDataAll, String> converter = TypeConverter.json(
    fromJson: (json) => LocalDataAll.fromJson(json as Map<String, Object?>),
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
