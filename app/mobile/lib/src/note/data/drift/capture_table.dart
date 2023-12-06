import 'package:drift/drift.dart';
import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'capture_table.g.dart';

enum CaptureTableType {
  audio(jsonName: "audio"),
  unknown(jsonName: "unknown");

  const CaptureTableType({required this.jsonName});

  final String jsonName;
}

class CaptureTable extends Table {
  @override
  String get tableName => 'capture';

  TextColumn get id => text()();
  TextColumn get type => text().map(CaptureTableTypeConverter())();
  TextColumn get localData => text().map(CaptureLocalDataAllConverter())();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CaptureTableTypeConverter
    extends TypeConverter<CaptureTableType, String> {
  @override
  CaptureTableType fromSql(String fromDb) {
    if (fromDb == CaptureTableType.audio.jsonName) {
      return CaptureTableType.audio;
    } else {
      return CaptureTableType.unknown;
    }
  }

  @override
  String toSql(CaptureTableType value) {
    switch (value) {
      case CaptureTableType.audio:
        return CaptureTableType.audio.jsonName;
      case CaptureTableType.unknown:
        return CaptureTableType.unknown.jsonName;
    }
  }
}

// Don't rename without migration.
enum CaptureLocalStatusRepo { capturing, captured, synced }

/// Local data for all capture types. Repo should convert to/from this to the
/// domain type.
@JsonSerializable()
class CaptureLocalDataAll {
  // All
  final CaptureLocalStatusRepo status;

  // Audio file
  final String? filePath;

  CaptureLocalDataAll({required this.status, this.filePath});

  factory CaptureLocalDataAll.fromJson(Map<String, Object?> json) =>
      _$CaptureLocalDataAllFromJson(json);

  Map<String, Object?> toJson() => _$CaptureLocalDataAllToJson(this);
}

class CaptureLocalDataAllConverter
    extends TypeConverter<CaptureLocalDataAll, String> {
  @override
  CaptureLocalDataAll fromSql(String fromDb) {
    return CaptureLocalDataAll.fromJson(
        json.decode(fromDb) as Map<String, Object?>);
  }

  @override
  String toSql(CaptureLocalDataAll value) {
    return jsonEncode(value.toJson());
  }
}
