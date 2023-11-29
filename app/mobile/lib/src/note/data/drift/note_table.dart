import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_table.g.dart';

// TODO: Make this more explicit using a property jsonName as per LocalStatusRepo
// Enum names are used in the database. So don't rename without handling the
// migration.
enum NoteTableType { voice, text }

class NoteTable extends Table {
  @override
  String get tableName => 'note';

  TextColumn get id => text()();
  TextColumn get type => textEnum<NoteTableType>()();
  TextColumn get title => text().nullable()();
  TextColumn get captures => text().map(NoteTableCapturesConverter())();
  TextColumn get localData => text().map(LocalDataAllConverter())();

  @override
  Set<Column> get primaryKey => {id};
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

enum LocalStatusRepo {
  capturing(jsonName: "capturing"),
  captured(jsonName: "captured"),
  synced(jsonName: "synced");

  const LocalStatusRepo({required this.jsonName});

  final String jsonName;
}

/// Local data for all note types. Repo should convert to/from this to the
/// domain type.
@JsonSerializable()
class LocalDataAll {
  final LocalStatusRepo status;
  final String filePath;

  LocalDataAll({required this.filePath, required this.status});

  factory LocalDataAll.fromJson(Map<String, Object?> json) =>
      _$LocalDataAllFromJson(json);

  Map<String, Object?> toJson() {
    return _$LocalDataAllToJson(this);
  }
}

class LocalDataAllConverter extends TypeConverter<LocalDataAll, String> {
  @override
  LocalDataAll fromSql(String fromDb) {
    return LocalDataAll.fromJson(json.decode(fromDb) as Map<String, Object?>);
  }

  @override
  String toSql(LocalDataAll value) {
    return jsonEncode(value.toJson());
  }
}
