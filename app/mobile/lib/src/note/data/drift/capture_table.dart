import 'package:drift/drift.dart';

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
