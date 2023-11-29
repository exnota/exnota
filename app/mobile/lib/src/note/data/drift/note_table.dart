import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_table.g.dart';

// Enum names are used in the database. So don't rename without handling the
// migration.
enum NoteTableType { voice, text }

class NoteTable extends Table {
  @override
  String get tableName => 'note';

  TextColumn get id => text()();
  TextColumn get type => textEnum<NoteTableType>()();
  TextColumn get title => text().nullable()();
  TextColumn get captures => text().map(NoteTableCaptures.converter)();
  TextColumn get localData => text().map(LocalDataAllConverter())();

  @override
  Set<Column> get primaryKey => {id};
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

@JsonSerializable()
class NoteTableCaptures {
  final List<String> captures;

  NoteTableCaptures({required this.captures});

  factory NoteTableCaptures.fromJson(Map<String, Object?> json) =>
      _$NoteTableCapturesFromJson(json);

  Map<String, Object?> toJson() {
    return _$NoteTableCapturesToJson(this);
  }

  static JsonTypeConverter<NoteTableCaptures, String> converter =
      TypeConverter.json(
    fromJson: (json) =>
        NoteTableCaptures.fromJson(json as Map<String, Object?>),
    toJson: (entries) => entries.toJson(),
  );
}

// stores preferences as strings
// class LocalDataConverter extends TypeConverter<LocalData, String> {
//   const LocalDataConverter();

//   @override
//   VoiceNoteLocalData fromSql(String fromDb) {
//     return VoiceNoteLocalDataRepoMapper.fromJson(
//         json.decode(fromDb) as Map<String, dynamic>);
//   }

//   @override
//   String toSql(LocalData value) {
//     switch (value) {
//       case VoiceNoteLocalData():
//         return jsonEncode(VoiceNoteLocalDataRepoMapper.toJson(value));
//     }
//   }
// }

// class VoiceNoteLocalDataConverter
//     extends TypeConverter<VoiceNoteLocalData, String> {
//   const VoiceNoteLocalDataConverter();

//   @override
//   VoiceNoteLocalData fromSql(String fromDb) {
//     return VoiceNoteLocalDataRepoMapper.fromJson(
//         json.decode(fromDb) as Map<String, dynamic>);
//   }

//   @override
//   String toSql(VoiceNoteLocalData value) {
//     return jsonEncode(VoiceNoteLocalDataRepoMapper.toJson(value));
//   }
// }
