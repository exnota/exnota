// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'block.freezed.dart';
part 'block.g.dart';

@freezed
class Block with _$Block {
  const factory Block({
    required String id,
    required BlockType type,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? external,
    List<String>? content,
    String? parentId,
    required DateTime createdAt,
    required DateTime lastEditedAt,
  }) = _Block;

  const Block._();

  String? get title => properties?[Property.title.toString()]?[0]?[0];

  String? get externalUrl => external?['url'];
}

enum BlockType { audio, text }

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum Property {
  title(dbName: 'title');

  const Property({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}
