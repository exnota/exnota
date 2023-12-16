import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'block.freezed.dart';

@freezed
class Block with _$Block {
  const factory Block({
    required String id,
    required BlockType type,
    required Map<String, List<List>> properties,
    required DateTime createdAt,
    required DateTime lastEditedAt,
  }) = _Block;

  const Block._();

  List<List> get transcription =>
      properties[Property.transcription.toString()]?[0][0]!;
}

enum BlockType {
  audio,
}

enum Property { transcription }
