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
    External? external,
    String? file,
    Audio? audio,
    required String userId,
    required DateTime userCreated,
    DateTime? created,
    DateTime? updated,
    DateTime? archived,
  }) = _Block;

  const Block._();

  factory Block.createAudio({
    required String id,
    required String userId,
    required DateTime userCreated,
  }) {
    return Block(
      id: id,
      type: BlockType.audio,
      userId: userId,
      userCreated: userCreated,
    );
  }

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

    External? external;
    final externalMap = model.data['external'];
    if (externalMap != null && externalMap is Map<String, dynamic>) {
      external = External.fromJson(externalMap);
    }

    return Block(
      id: model.id,
      title: model.data['title'],
      type: type,
      external: external,
      file: model.data['file'],
      audio: audio,
      userId: model.data['user'],
      userCreated: DateTime.tryParse(model.data['userCreated'])!,
      created: DateTime.tryParse(model.created),
      updated: DateTime.tryParse(model.updated),
      archived: DateTime.tryParse(model.data['archived']),
    );
  }

  Map<String, dynamic> toCreateRequestBody({required String? destinationId}) {
    Map<String, dynamic> body = {
      'id': id,
    };

    if (title != null) {
      body['title'] = title;
    }

    switch (type) {
      case BlockType.audio:
        body['type'] = 'voice-note';
        break;
      case BlockType.text:
        body['type'] = 'text-note';
        break;
      case BlockType.unknown:
        throw Exception('Unknown block type');
    }

    // Ignore external, file, audio. They won't be initialized locally.
    body['user'] = userId;
    body['userCreated'] = userCreated.toIso8601String();
    // Ignore created, updated. They will be set by the server.
    if (archived != null) {
      body['archived'] = archived!.toIso8601String();
    }

    if (destinationId != null) {
      body['destination'] = destinationId;
    }

    return body;
  }
}

enum BlockType { audio, text, unknown }

@freezed
class Audio with _$Audio {
  const factory Audio({List<String>? transcription}) = _Audio;

  const Audio._();

  factory Audio.fromJson(Map<String, dynamic> json) => _$AudioFromJson(json);
}

@freezed
class External with _$External {
  const factory External({String? url}) = _External;

  const External._();

  factory External.fromJson(Map<String, dynamic> json) =>
      _$ExternalFromJson(json);
}
