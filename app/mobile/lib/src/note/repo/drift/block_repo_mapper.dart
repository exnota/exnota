import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';

class BlockRepoMapper {
  static Block fromRepo(BlockTableData repo) {
    return Block(
      id: repo.id,
      title: repo.title,
      type: _typeFromRepo(repo.type),
      externalUrl: repo.externalUrl,
      file: repo.file,
      audio: _fromAudioRepo(repo.audio),
      userId: repo.user,
      userCreated: repo.userCreated,
      created: repo.created,
      updated: repo.updated,
      archived: repo.archived,
    );
  }

  static BlockType _typeFromRepo(String type) {
    switch (type) {
      case 'audio':
        return BlockType.audio;
      case 'text':
        return BlockType.text;
      default:
        return BlockType.unknown;
    }
  }

  static Audio? _fromAudioRepo(String? audio) {
    if (audio == null) {
      return null;
    }

    final json = jsonDecode(audio) as Map<String, dynamic>;
    final transcription = json['transcription'];
    if (transcription is List) {
      return Audio(transcription: transcription.cast<String>());
    } else {
      return const Audio(transcription: null);
    }
  }
}
