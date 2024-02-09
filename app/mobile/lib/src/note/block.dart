// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'block.freezed.dart';

@freezed
class Block with _$Block {
  const factory Block({
    required String id,
    String? title,
    required BlockType type,
    String? externalUrl,
    String? file,
    Audio? audio,
    required String userId,
    required DateTime userCreated,
    DateTime? created,
    DateTime? updated,
    DateTime? archived,
  }) = _Block;

  const Block._();
}

enum BlockType { audio, text, unknown }

@freezed
class Audio with _$Audio {
  const factory Audio({List<String>? transcription}) = _Audio;

  const Audio._();
}
