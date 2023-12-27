import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';

class BlockRepoMapper {
  static BlockTableData toRepo(Block block) {
    return BlockTableData(
      id: block.id,
      type: _toStatusRepo(block.type),
      properties: toPropertiesRepo(block.properties),
      external: toExternalRepo(block.external),
      content: toContentRepo(block.content),
      parentId: block.parentId,
      createdAt: block.createdAt,
      lastEditedAt: block.lastEditedAt,
    );
  }

  static Block fromRepo(BlockTableData block) {
    return Block(
      id: block.id,
      type: _fromStatusRepo(block.type),
      properties: fromPropertiesRepo(block.properties),
      external: fromExternalRepo(block.external),
      content: fromContentRepo(block.content),
      parentId: block.parentId,
      createdAt: block.createdAt,
      lastEditedAt: block.lastEditedAt,
    );
  }

  static BlockTypeRepo _toStatusRepo(BlockType type) {
    switch (type) {
      case BlockType.audio:
        return BlockTypeRepo.audio;
      case BlockType.text:
        return BlockTypeRepo.text;
    }
  }

  static BlockType _fromStatusRepo(BlockTypeRepo type) {
    switch (type) {
      case BlockTypeRepo.audio:
        return BlockType.audio;
      case BlockTypeRepo.text:
        return BlockType.text;
    }
  }

  static String? toPropertiesRepo(Map<String, dynamic>? properties) {
    if (properties == null) {
      return null;
    }
    return jsonEncode(properties);
  }

  static Map<String, dynamic>? fromPropertiesRepo(String? properties) {
    if (properties == null) {
      return null;
    }

    return jsonDecode(properties) as Map<String, dynamic>;
  }

  static String? toExternalRepo(Map<String, dynamic>? external) {
    if (external == null) {
      return null;
    }

    return jsonEncode(external);
  }

  static Map<String, dynamic>? fromExternalRepo(String? external) {
    if (external == null) {
      return null;
    }

    return jsonDecode(external) as Map<String, dynamic>;
  }

  static String? toContentRepo(List<String>? content) {
    if (content == null) {
      return null;
    }

    return jsonEncode(content);
  }

  static List<String>? fromContentRepo(String? content) {
    if (content == null) {
      return null;
    }

    final decoded = jsonDecode(content) as List;
    return decoded.map((c) => c as String).toList();
  }
}
