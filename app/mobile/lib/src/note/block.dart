import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'block.freezed.dart';

@freezed
class Block with _$Block {
  const factory Block({
    required String id,
    required BlockType type,
    required Map<String, dynamic> properties,
    required DateTime createdAt,
    required DateTime lastEditedAt,
  }) = _Block;

  const Block._();

  String get title => properties[Property.title.toString()]?[0][0]!;
}

enum BlockType {
  audio,
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum Property {
  title(dbName: 'title');

  const Property({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}
