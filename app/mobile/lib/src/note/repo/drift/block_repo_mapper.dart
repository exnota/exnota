import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';

class BlockRepoMapper {
  static BlockTableData toRepo(Block block) {
    return BlockTableData(
      id: block.id,
      type: _toStatusRepo(block.type),
      properties: _toPropertiesRepo(block.properties),
      createdAt: block.createdAt,
      lastEditedAt: block.lastEditedAt,
    );
  }

  static Block fromRepo(BlockTableData block) {
    return Block(
      id: block.id,
      type: _fromStatusRepo(block.type),
      properties: _fromPropertiesRepo(block.properties),
      createdAt: block.createdAt,
      lastEditedAt: block.lastEditedAt,
    );
  }

  static BlockTypeRepo _toStatusRepo(BlockType type) {
    switch (type) {
      case BlockType.audio:
        return BlockTypeRepo.audio;
    }
  }

  static BlockType _fromStatusRepo(BlockTypeRepo type) {
    switch (type) {
      case BlockTypeRepo.audio:
        return BlockType.audio;
    }
  }

  static String _toPropertiesRepo(Map<String, dynamic> properties) {
    return jsonEncode(properties);
  }

  static Map<String, dynamic> _fromPropertiesRepo(String properties) {
    return jsonDecode(properties) as Map<String, dynamic>;
  }
}
