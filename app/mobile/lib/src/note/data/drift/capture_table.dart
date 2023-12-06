import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'capture_table.g.dart';

class CaptureTable extends Table {
  @override
  String get tableName => 'capture';

  TextColumn get id => text()();
  TextColumn get type => text().map(CaptureTableTypeConverter())();
  TextColumn get localData => text().map(CaptureLocalDataAll.converter)();
  TextColumn get typeData => text().map(CaptureTypeDataAll.converter)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

enum CaptureTableType {
  audio(jsonName: "audio"),
  unknown(jsonName: "unknown");

  const CaptureTableType({required this.jsonName});

  final String jsonName;
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
@JsonSerializable(constructor: '_')
class CaptureLocalDataAll {
  // All
  final CaptureLocalStatusRepo status;

  // Audio file
  final String? filePath;

  CaptureLocalDataAll._({required this.status, this.filePath});

  CaptureLocalDataAll.audioFile(
      {required CaptureLocalStatusRepo status, required String? filePath})
      : this._(status: status, filePath: filePath);

  CaptureLocalDataAll.unknown({required CaptureLocalStatusRepo status})
      : this._(status: status);

  factory CaptureLocalDataAll.fromJson(Map<String, Object?> json) =>
      _$CaptureLocalDataAllFromJson(json);

  Map<String, Object?> toJson() => _$CaptureLocalDataAllToJson(this);

  static TypeConverter<CaptureLocalDataAll, String> converter =
      TypeConverter.json(
    fromJson: (json) =>
        CaptureLocalDataAll.fromJson(json as Map<String, Object?>),
    toJson: (pref) => pref.toJson(),
  );
}

/// Type-specific data for all capture types. Repo should convert to/from this
/// to the domain type.
@JsonSerializable(constructor: '_')
class CaptureTypeDataAll {
  // Audio file
  final String? transcription;

  CaptureTypeDataAll._({this.transcription});

  CaptureTypeDataAll.audioFile({required String? transcription})
      : this._(transcription: transcription);

  CaptureTypeDataAll.unknown() : this._();

  factory CaptureTypeDataAll.fromJson(Map<String, Object?> json) =>
      _$CaptureTypeDataAllFromJson(json);

  Map<String, Object?> toJson() => _$CaptureTypeDataAllToJson(this);

  static TypeConverter<CaptureTypeDataAll, String> converter =
      TypeConverter.json(
    fromJson: (json) =>
        CaptureTypeDataAll.fromJson(json as Map<String, Object?>),
    toJson: (pref) => pref.toJson(),
  );
}
