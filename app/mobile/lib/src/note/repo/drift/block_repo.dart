import 'dart:math';

import 'package:drift/drift.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/operation.dart';
import 'package:exnota/src/note/repo/drift/block_repo_mapper.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:flutter/foundation.dart';

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
        final now = DateTime.now();
        for (final operation in operations) {
          switch (operation.type) {
            case OperationType.listAfter:
              // Currently only supports content
              if (!listEquals(operation.path, [BaseArg.content.toString()])) {
                logger
                    .error('Only [\'content\'] is supported', nonPrivateData: {
                  "path": operation.path,
                });
                throw UnsupportedError('Only [\'content\'] is supported]');
              }

              // Find pointer block
              final pointerId = operation.pointer.id;
              final query = db.select(db.blockTable)
                ..where((tbl) => tbl.id.equals(pointerId));
              final blockData = await query.getSingleOrNull();
              if (blockData == null) {
                logger.error('Block does not exist', nonPrivateData: {
                  "pointerId": pointerId,
                });
                throw StateError('Block does not exist');
              }
              final block = BlockRepoMapper.fromRepo(blockData);

              // Get and validate arguments
              final after =
                  operation.args[ListAfterArg.after.toString()] as String?;
              final id = operation.args[ListAfterArg.id.toString()] as String;
              if (id == pointerId) {
                logger.error('A block\'s content cannot contain itself',
                    nonPrivateData: {
                      "pointerId": pointerId,
                      "id": id,
                    });
                throw ArgumentError('A block\'s content cannot contain itself');
              }
              final idQuery = db.select(db.blockTable)
                ..where((tbl) => tbl.id.equals(id));
              final idBlock = await idQuery.getSingleOrNull();
              if (idBlock == null) {
                logger.error('Block for id does not exist', nonPrivateData: {
                  "id": id,
                });
                throw StateError('Block does not exist');
              }

              // Insert into correct place in content array.
              // If after exists but isn't found, insert at the end.
              final updatedContent =
                  List<String>.from(block.content ?? List.empty());
              int insertAt = max(0, updatedContent.length);
              if (after != null) {
                final afterIndex = updatedContent.indexOf(after);
                insertAt = afterIndex == -1 ? insertAt : afterIndex + 1;
              }
              updatedContent.insert(insertAt, id);

              // Update
              final update = BlockTableCompanion(
                lastEditedAt: Value(now),
                content: Value(BlockRepoMapper.toContentRepo(updatedContent)),
              );
              await (db.update(db.blockTable)
                    ..where((tbl) => tbl.id.equals(pointerId)))
                  .write(update);
              break;
            case OperationType.update:
              // Get existing block
              final pointerId = operation.pointer.id;
              final query = db.select(db.blockTable)
                ..where((tbl) => tbl.id.equals(pointerId));
              final existing = await query.getSingleOrNull();
              if (existing == null) {
                logger.error('Block does not exist', nonPrivateData: {
                  "pointerId": pointerId,
                });
                throw StateError('Block does not exist');
              }

              // Generate updated block companion based on path
              final path = operation.path;
              BlockTableCompanion updated;
              if (path.isNotEmpty &&
                  path.first == BaseArg.external.toString()) {
                updated =
                    _forPathExternal(operation: operation, block: existing);
              } else {
                logger.error('Unsupported path for \'update\' operation',
                    nonPrivateData: {
                      "path": path,
                    });
                throw UnsupportedError(
                    'Unsupported path for \'update\' operation');
              }

              // Persist block
              await db.update(db.blockTable).write(updated);
              break;
            case OperationType.set:
              // Verify block doesn't exist.
              // For now, 'set' is just for creates.
              final pointerId = operation.pointer.id;
              final query = db.select(db.blockTable)
                ..where((tbl) => tbl.id.equals(pointerId));
              final existing = await query.getSingleOrNull();
              if (existing != null) {
                logger.error('Block already exists', nonPrivateData: {
                  "pointerId": pointerId,
                });
                throw StateError('Block already exists');
              }

              // Verify path is empty
              final path = operation.path;
              if (path.isNotEmpty) {
                logger.error('Unsupported path for \'set\' operation',
                    nonPrivateData: {
                      "path": path,
                    });
                throw UnsupportedError(
                    'Unsupported path for \'set\' operation');
              }

              // Id - required while 'set' is just for creates.
              final id = operation.args[BaseArg.id.toString()] as String;
              if (pointerId != id) {
                logger.error('Id must match pointer id', nonPrivateData: {
                  "pointerId": pointerId,
                  "id": id,
                });
                throw ArgumentError('Id must match pointer id');
              }

              // type - required while 'set' is just for creates.
              final typeStr = operation.args[BaseArg.type.toString()] as String;
              late BlockTypeRepo type;
              if (typeStr == BlockType.audio.toString()) {
                type = BlockTypeRepo.audio;
              } else {
                throw UnsupportedError('Unknown block type: $typeStr');
              }

              // properties
              final properties = operation.args[BaseArg.properties.toString()]
                  as Map<String, dynamic>?;

              // times - required while 'set' is just for creates.
              final createdAt =
                  DateTime.parse(operation.args[BaseArg.createdAt.toString()]);
              final lastEditedAt = DateTime.parse(
                  operation.args[BaseArg.lastEditedAt.toString()]);

              // Persist block
              final block = BlockTableData(
                  id: id,
                  type: type,
                  properties: BlockRepoMapper.toPropertiesRepo(properties),
                  createdAt: createdAt,
                  lastEditedAt: lastEditedAt);
              await db.into(db.blockTable).insert(block);
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

  BlockTableCompanion _forPathExternal(
      {required Operation operation, required BlockTableData block}) {
    // Only supports ['external', 'url']
    final path = operation.path;
    if (path.length == 1) {
      logger
          .error('Only [\'external\', \'url\'] is supported', nonPrivateData: {
        "path": path,
      });
      throw UnsupportedError('Only [\'external\', \'url\'] is supported');
    }
    final propertyPath = path[1];
    if (propertyPath != ExternalKey.url.toString()) {
      logger.error('Only [\'url\'] is supported', nonPrivateData: {
        "propertyPath": propertyPath,
      });
      throw UnsupportedError('Only [\'url\'] is supported');
    }

    // Get arguments
    final url = operation.args[SingleValArg.val.toString()] as String?;

    final External updatedExternal = (url: url);
    return BlockTableCompanion(
      external: Value(BlockRepoMapper.toExternalRepo(updatedExternal)),
    );
  }
}
