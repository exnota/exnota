import 'package:drift/drift.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_table.g.dart';

// Enum names are used in the database. So don't rename without handling the
// migration.
enum NoteTableType { voice, text }

class NoteTable extends Table {
  @override
  String get tableName => 'note';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<NoteTableType>()();
  TextColumn get title => text().nullable()();
  TextColumn get captures => text().map(NoteTableCaptures.converter)();
}

@JsonSerializable()
class NoteTableCaptures {
  final List<int> captures;

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
