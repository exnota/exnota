import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/block/block.dart';

class BlockRepoMapper {
  static Block fromRepo(BlockTableData repo) {
    return Block(
      id: repo.id,
      title: repo.title,
      type: _typeFromRepo(repo.type),
      external: _fromExternalRepo(repo.external),
      file: repo.file,
      audio: _fromAudioRepo(repo.audio),
      userId: repo.user,
      userCreated: repo.userCreated,
      created: repo.created,
      updated: repo.updated,
      archived: repo.archived,
    );
  }

  static BlockTableData toRepo(Block block) {
    return BlockTableData(
      id: block.id,
      title: block.title,
      type: _typeToRepo(block.type),
      external: _toExternalRepo(block.external),
      file: block.file,
      audio: _toAudioRepo(block.audio),
      user: block.userId,
      userCreated: block.userCreated,
      created: block.created,
      updated: block.updated,
      archived: block.archived,
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

  static String _typeToRepo(BlockType type) {
    switch (type) {
      case BlockType.audio:
        return 'audio';
      case BlockType.text:
        return 'text';
      case BlockType.unknown:
        return 'unknown';
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

  static String? _toAudioRepo(Audio? audio) {
    if (audio == null) {
      return null;
    }

    return jsonEncode({'transcription': audio.transcription});
  }

  static External? _fromExternalRepo(String? external) {
    if (external == null) {
      return null;
    }
    final json = jsonDecode(external) as Map<String, dynamic>;
    final url = json['url'];
    if (url is String) {
      return External(url: url);
    } else {
      return const External(url: null);
    }
  }

  static String? _toExternalRepo(External? external) {
    if (external == null) {
      return null;
    }

    return jsonEncode({'url': external.url});
  }
}
