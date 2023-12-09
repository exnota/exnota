import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'capture_table.g.dart';

class CaptureTable extends Table {
  @override
  String get tableName => 'capture';

  TextColumn get id => text()();
  TextColumn get type => text().map(CaptureTypeRepoConverter())();
  TextColumn get localData => text().map(CaptureLocalDataRepo.converter)();
  TextColumn get typeData => text().map(CaptureTypeDataRepo.converter)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

enum CaptureTypeRepo {
  audio(jsonName: "audio"),
  unknown(jsonName: "unknown");

  const CaptureTypeRepo({required this.jsonName});

  final String jsonName;
}

class CaptureTypeRepoConverter extends TypeConverter<CaptureTypeRepo, String> {
  @override
  CaptureTypeRepo fromSql(String fromDb) {
    if (fromDb == CaptureTypeRepo.audio.jsonName) {
      return CaptureTypeRepo.audio;
    } else {
      return CaptureTypeRepo.unknown;
    }
  }

  @override
  String toSql(CaptureTypeRepo value) {
    switch (value) {
      case CaptureTypeRepo.audio:
        return CaptureTypeRepo.audio.jsonName;
      case CaptureTypeRepo.unknown:
        return CaptureTypeRepo.unknown.jsonName;
    }
  }
}

// TODO:
// Don't rename without migration.
enum CaptureLocalStatusRepo { capturing, captured, synced }

/// Local data for all capture types. Repo should convert to/from this to the
/// domain type.
@JsonSerializable(constructor: '_')
class CaptureLocalDataRepo {
  // All
  final CaptureLocalStatusRepo status;

  // Audio file
  final String? filePath;

  CaptureLocalDataRepo._({required this.status, this.filePath});

  CaptureLocalDataRepo.audioFile(
      {required CaptureLocalStatusRepo status, required String? filePath})
      : this._(status: status, filePath: filePath);

  CaptureLocalDataRepo.unknown({required CaptureLocalStatusRepo status})
      : this._(status: status);

  factory CaptureLocalDataRepo.fromJson(Map<String, Object?> json) =>
      _$CaptureLocalDataRepoFromJson(json);

  Map<String, Object?> toJson() => _$CaptureLocalDataRepoToJson(this);

  static TypeConverter<CaptureLocalDataRepo, String> converter =
      TypeConverter.json(
    fromJson: (json) =>
        CaptureLocalDataRepo.fromJson(json as Map<String, Object?>),
    toJson: (pref) => pref.toJson(),
  );
}

/// Type-specific data for all capture types. Repo should convert to/from this
/// to the domain type.
@JsonSerializable(constructor: '_')
class CaptureTypeDataRepo {
  // Audio file
  final String? transcription;

  CaptureTypeDataRepo._({this.transcription});

  CaptureTypeDataRepo.audioFile({required String? transcription})
      : this._(transcription: transcription);

  CaptureTypeDataRepo.unknown() : this._();

  factory CaptureTypeDataRepo.fromJson(Map<String, Object?> json) =>
      _$CaptureTypeDataRepoFromJson(json);

  Map<String, Object?> toJson() => _$CaptureTypeDataRepoToJson(this);

  static TypeConverter<CaptureTypeDataRepo, String> converter =
      TypeConverter.json(
    fromJson: (json) =>
        CaptureTypeDataRepo.fromJson(json as Map<String, Object?>),
    toJson: (pref) => pref.toJson(),
  );
}
