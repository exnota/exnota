import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/operation.dart';
import 'package:exnota/src/note/repo/drift/block_repo_mapper.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';
import 'package:exnota/src/note/transaction.dart';

class BlockRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  BlockRepo(this.db);

  Stream<List<Block>> listWatch() {
    final query = db.select(db.blockTable);
    query.orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.map(BlockRepoMapper.fromRepo).watch();
  }

  Future<void> create({required Block block}) async {
    final blockData = BlockRepoMapper.toRepo(block);
    await db.into(db.blockTable).insert(blockData);
  }

  Future<void> executeTransaction({required Transaction transaction}) async {
    await db.transaction(() async {
      try {
        final operations = transaction.operations;
        for (final operation in operations) {
          switch (operation.type) {
            case OperationType.set:
              final blockId = operation.pointer.id;
              final query = db.select(db.blockTable)
                ..where((tbl) => tbl.id.equals(blockId));
              final existing = await query.getSingleOrNull();

              // Path
              final path = operation.path;
              if (path.isNotEmpty) {
                throw Exception('Path is not empty');
              }

              // Root path args
              // type
              final typeStr = operation.args[ArgKey.type.toString()] as String;
              late BlockTypeRepo type;
              if (typeStr == BlockType.audio.toString()) {
                type = BlockTypeRepo.audio;
              } else {
                throw Exception('Unknown block type: $typeStr');
              }

              // properties
              final properties = operation.args[ArgKey.properties.toString()]
                  as Map<String, dynamic>?;
              // TODO: Create PropertyArgKey in operation.dart

              // times
              final createdAt =
                  DateTime.parse(operation.args[ArgKey.createdAt.toString()]);
              final lastEditedAt = DateTime.parse(
                  operation.args[ArgKey.lastEditedAt.toString()]);

              // If the block doesn't exist, create it.
              if (existing == null) {
                final block = BlockTableData(
                    id: blockId,
                    type: type,
                    properties: jsonEncode(properties ?? {}),
                    createdAt: createdAt,
                    lastEditedAt: lastEditedAt);
                await db.into(db.blockTable).insert(block);
                return;
              }

              // If the block exists, update it.
              // TODO: Merge existing properties with new
              final block = BlockTableCompanion(
                id: Value(blockId),
                type: Value(type),
                properties: Value(jsonEncode(properties)),
                createdAt: Value(createdAt),
                lastEditedAt: Value(lastEditedAt),
              );
              await db.update(db.blockTable).replace(block);
          }
        }
      } catch (e, stackTrace) {
        logger.error('Error executing transaction', nonPrivateData: {
          "error": e,
          "stackTrace": stackTrace,
        });
        rethrow;
      }
    });
  }
}
