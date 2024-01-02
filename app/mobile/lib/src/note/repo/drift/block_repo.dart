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
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_repo.g.dart';

@riverpod
BlockRepo blockRepo(BlockRepoRef ref) {
  final db = ref.read(databaseProvider);
  return BlockRepo(db);
}

class BlockRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  BlockRepo(this.db);

  Stream<List<Block>> listWatch({bool onlyRoot = true}) {
    final query = db.select(db.blockTable);
    if (onlyRoot) {
      query.where((tbl) => tbl.parentId.isNull());
    }
    query.orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.map(BlockRepoMapper.fromRepo).watch();
  }

  Future<void> create({required Block block}) async {
    final blockData = BlockRepoMapper.toRepo(block);
    await db.into(db.blockTable).insert(blockData);
  }

  Future<Block> get({required String id}) async {
    final query = db.select(db.blockTable)..where((tbl) => tbl.id.equals(id));
    final blockData = await query.getSingle();
    return BlockRepoMapper.fromRepo(blockData);
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
              if (!listEquals(operation.path, [Prop.content.toString()])) {
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
              if (path.isNotEmpty && path.first == Prop.external.toString()) {
                updated =
                    _forPathExternal(operation: operation, block: existing);
              } else if (path.isNotEmpty &&
                  path.first == Prop.properties.toString()) {
                updated =
                    _forPathProperties(operation: operation, block: existing);
              } else if (path.isNotEmpty &&
                  path.single == Prop.lastEditedAt.toString()) {
                updated =
                    _forPathLastEditedAt(operation: operation, block: existing);
              } else if (path.isEmpty) {
                updated = BlockTableCompanion(
                  lastEditedAt: Value(now),
                );
              } else {
                logger.error('Unsupported path for \'update\' operation',
                    nonPrivateData: {
                      "path": path,
                    });
                throw UnsupportedError(
                    'Unsupported path for \'update\' operation');
              }

              // Persist block
              await (db.update(db.blockTable)
                    ..where((tbl) => tbl.id.equals(pointerId)))
                  .write(updated);
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
              final id = operation.args[Prop.id.toString()] as String;
              if (pointerId != id) {
                logger.error('Id must match pointer id', nonPrivateData: {
                  "pointerId": pointerId,
                  "id": id,
                });
                throw ArgumentError('Id must match pointer id');
              }

              // type - required while 'set' is just for creates.
              final typeStr = operation.args[Prop.type.toString()] as String;
              late BlockTypeRepo type;
              if (typeStr == BlockType.audio.toString()) {
                type = BlockTypeRepo.audio;
              } else if (typeStr == BlockType.text.toString()) {
                type = BlockTypeRepo.text;
              } else {
                throw UnsupportedError('Unknown block type: $typeStr');
              }

              // times - required while 'set' is just for creates.
              final createdAt =
                  DateTime.parse(operation.args[Prop.createdAt.toString()]);
              final lastEditedAt =
                  DateTime.parse(operation.args[Prop.lastEditedAt.toString()]);

              // properties
              final properties = operation.args[Prop.properties.toString()]
                  as Map<String, dynamic>?;

              // external
              final external = operation.args[Prop.external.toString()]
                  as Map<String, dynamic>?;

              // content
              final content =
                  operation.args[Prop.content.toString()] as List<String>?;

              // parentId
              final parentId =
                  operation.args[Prop.parentId.toString()] as String?;

              // Persist block
              final block = BlockTableData(
                  id: id,
                  type: type,
                  properties: BlockRepoMapper.toPropertiesRepo(properties),
                  external: BlockRepoMapper.toExternalRepo(external),
                  content: BlockRepoMapper.toContentRepo(content),
                  parentId: parentId,
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
    if (propertyPath != PrepExternal.url.toString()) {
      logger.error('Only [\'url\'] is supported', nonPrivateData: {
        "propertyPath": propertyPath,
      });
      throw UnsupportedError('Only [\'url\'] is supported');
    }

    // Get arguments
    final url = operation.args[SingleVal.val.toString()] as String?;
    final isEmpty = url?.isEmpty ?? false;

    final updatedExternal =
        BlockRepoMapper.fromExternalRepo(block.external) ?? {};
    updatedExternal["url"] = isEmpty ? null : url;

    return BlockTableCompanion(
      external: Value(BlockRepoMapper.toExternalRepo(updatedExternal)),
    );
  }

  BlockTableCompanion _forPathProperties({
    required Operation operation,
    required BlockTableData block,
  }) {
    // Only supports ['properties', 'title']
    final path = operation.path;
    if (path.length == 1) {
      logger.error('Only [\'properties\', \'title\'] is supported',
          nonPrivateData: {
            "path": path,
          });
      throw UnsupportedError('Only [\'properties\', \'title\'] is supported');
    }
    final propertyPath = path[1];
    if (propertyPath != Property.title.toString()) {
      logger.error('Only [\'title\'] is supported', nonPrivateData: {
        "propertyPath": propertyPath,
      });
      throw UnsupportedError('Only [\'title\'] is supported');
    }

    // Get arguments
    final title =
        operation.args[SingleVal.val.toString()] as List<List<String>>?;
    final isEmpty = title?.isEmpty ?? false;

    final updatedProperties =
        BlockRepoMapper.fromPropertiesRepo(block.properties) ?? {};
    updatedProperties["title"] = isEmpty ? null : title;

    return BlockTableCompanion(
      properties: Value(BlockRepoMapper.toPropertiesRepo(updatedProperties)),
    );
  }

  BlockTableCompanion _forPathLastEditedAt(
      {required Operation operation, required BlockTableData block}) {
    // Get argument
    final lastEditedAt = operation.args[SingleVal.val.toString()] as String?;
    // if empty, throw
    if (lastEditedAt == null || lastEditedAt.isEmpty) {
      logger.error('Last edited at cannot be empty', nonPrivateData: {
        "lastEditedAt": lastEditedAt,
        "blockType": operation.type
      });
      throw ArgumentError('Last edited at cannot be empty');
    }

    return BlockTableCompanion(
      lastEditedAt: Value(DateTime.parse(lastEditedAt)),
    );
  }
}
