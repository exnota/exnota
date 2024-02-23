// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'block.freezed.dart';
part 'block.g.dart';

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

  factory Block.fromRecord(RecordModel model) {
    final BlockType type;
    switch (model.data['type']) {
      case 'audio':
        type = BlockType.audio;
        break;
      case 'text':
        type = BlockType.text;
        break;
      default:
        type = BlockType.unknown;
    }

    Audio? audio;
    final audioMap = model.data['audio'];
    if (audioMap != null && audioMap is Map<String, dynamic>) {
      audio = Audio.fromJson(audioMap);
    }

    return Block(
      id: model.id,
      title: model.data['title'],
      type: type,
      externalUrl: model.data['externalUrl'],
      file: model.data['file'],
      audio: audio,
      userId: model.data['user'],
      userCreated: DateTime.tryParse(model.data['userCreated'])!,
      created: DateTime.tryParse(model.created),
      updated: DateTime.tryParse(model.updated),
      archived: DateTime.tryParse(model.data['archived']),
    );
  }
}

enum BlockType { audio, text, unknown }

@freezed
class Audio with _$Audio {
  const factory Audio({List<String>? transcription}) = _Audio;

  const Audio._();

  factory Audio.fromJson(Map<String, dynamic> json) => _$AudioFromJson(json);
}
