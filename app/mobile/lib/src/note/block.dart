import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'block.freezed.dart';

typedef External = ({
  String? url,
});

@freezed
class Block with _$Block {
  const factory Block({
    required String id,
    required BlockType type,
    Map<String, dynamic>? properties,
    External? external,
    List<String>? content,
    String? parentId,
    required DateTime createdAt,
    required DateTime lastEditedAt,
  }) = _Block;

  const Block._();

  String? get title => properties?[Property.title.toString()]?[0]?[0];
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

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum ExternalKey {
  url(dbName: 'url');

  const ExternalKey({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}
