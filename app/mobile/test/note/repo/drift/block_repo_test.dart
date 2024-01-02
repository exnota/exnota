import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/operation.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('BlockRepo', () {
    group('list', () {
      group('given no blocks', () {
        test('returns empty list', () async {
          final repo = BlockRepo(db);
          final stream = repo.listWatch();
          expect(stream, emits([]));
        });
      });
      group('given two blocks', () {
        late DateTime now;
        setUp(() async {
          now = DateTime.now();
          final block1 = BlockTableData(
              id: 'block1',
              type: BlockTypeRepo.audio,
              properties: '{"title":[["a title"]]}',
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              lastEditedAt: now);
          final block2 = BlockTableData(
              id: 'block2',
              type: BlockTypeRepo.audio,
              properties: '{"title":[["a title"]]}',
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: now);
          await db.into(db.blockTable).insert(block1);
          await db.into(db.blockTable).insert(block2);
        });
        test('returns both blocks with most recently created first', () async {
          final repo = BlockRepo(db);
          final stream = repo.listWatch().timeout(const Duration(seconds: 30));
          expectLater(
              stream,
              emitsInOrder([
                predicate<List<Block>>((blocks) {
                  expect(blocks, hasLength(2));

                  // First
                  final block = blocks[0];
                  expect(block.id, 'block2');
                  expect(block.type, BlockType.audio);
                  expect(block.properties, {
                    Property.title.toString(): [
                      ['a title']
                    ]
                  });
                  expect(block.title, 'a title');
                  expect(
                      block.createdAt, DateTime.utc(1879, DateTime.march, 14));
                  expect(block.lastEditedAt, now);

                  // Second
                  final block2 = blocks[1];
                  expect(block2.id, 'block1');
                  expect(block2.type, BlockType.audio);
                  expect(block2.properties, {
                    Property.title.toString(): [
                      ['a title']
                    ]
                  });
                  expect(block2.title, 'a title');
                  expect(block2.createdAt,
                      DateTime.utc(1809, DateTime.february, 12));
                  expect(block2.lastEditedAt, now);

                  return true;
                }),
              ]));
        });
      });
    });
    group('get', () {
      group('Given a request for a block that does not exist', () {
        late DateTime now;
        setUp(() async {
          now = DateTime.now();
          final block1 = BlockTableData(
              id: 'block1',
              type: BlockTypeRepo.audio,
              properties: '{"title":[["a title"]]}',
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              lastEditedAt: now);
          await db.into(db.blockTable).insert(block1);
        });
        test('Then it throws an exception', () {
          final repo = BlockRepo(db);
          expectLater(
              () => repo.get(id: 'unknown block'), throwsA(isA<StateError>()));
        });
      });
      group('Given a request for a block that exists', () {
        setUp(() async {
          final block1 = BlockTableData(
              id: 'block1',
              type: BlockTypeRepo.audio,
              properties: '{"title":[["a title"]]}',
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              lastEditedAt: DateTime.utc(1809, DateTime.february, 12));
          await db.into(db.blockTable).insert(block1);
        });
        test('Then it returns the block', () async {
          final repo = BlockRepo(db);
          final block = await repo.get(id: 'block1');
          expect(block.id, 'block1');
          expect(block.type, BlockType.audio);
          expect(block.properties, {
            Property.title.toString(): [
              ['a title']
            ]
          });
          expect(block.title, 'a title');
          expect(block.createdAt, DateTime.utc(1809, DateTime.february, 12));
          expect(block.lastEditedAt, DateTime.utc(1809, DateTime.february, 12));
        });
      });
    });
    group('create', () {
      test('persists the given block', () async {
        final repo = BlockRepo(db);
        final now = DateTime.now();
        final input = Block(
            id: 'block id',
            type: BlockType.audio,
            properties: {
              Property.title.toString(): [
                ['a title']
              ]
            },
            createdAt: now,
            lastEditedAt: now);
        await repo.create(block: input);
        final output = await db.select(db.blockTable).getSingle();
        expect(output.id, input.id);
        expect(output.type, BlockTypeRepo.audio);
        expect(output.properties, '{"title":[["a title"]]}');
        expect(output.createdAt, input.createdAt);
        expect(output.lastEditedAt, input.lastEditedAt);
      });
    });
    group('executeTransaction', () {
      group('listAfter', () {
        group('Given two blocks and a valid operation', () {
          const validOperation = Operation(
              type: OperationType.listAfter,
              path: ['content'],
              pointer: (id: 'block1'),
              args: {"id": 'block2'});

          setUp(() {
            final block1 = BlockTableData(
                id: 'block1',
                type: BlockTypeRepo.audio,
                properties: '{"title":[["title 1"]]}',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                lastEditedAt: DateTime.now());
            final block2 = BlockTableData(
                id: 'block2',
                type: BlockTypeRepo.text,
                properties: '{"title":[["title 2"]]}',
                createdAt: DateTime.utc(1879, DateTime.march, 14),
                lastEditedAt: DateTime.now());
            db.into(db.blockTable).insert(block1);
            db.into(db.blockTable).insert(block2);
          });
          group('When the operation is unmodified', () {
            test('Then the operation executes successfully', () {
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction:
                          const Transaction(operations: [validOperation])),
                  returnsNormally);
            });
          });
          group('When the operation is given an invalid path', () {
            test('Then it throws a unsupported error', () async {
              final operation = validOperation.copyWith(path: ['properties']);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<UnsupportedError>()));
            });
          });
          group('When the operation is given a non-existing pointer', () {
            test('Then it throws a state error', () async {
              final operation =
                  validOperation.copyWith(pointer: (id: 'block3'));
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<StateError>()));
            });
          });
          group(
              'When the operation is given an id arg that matches the pointer',
              () {
            test('Then it throws an argument error', () async {
              final operation = validOperation.copyWith(args: {"id": 'block1'});
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<ArgumentError>()));
            });
          });
          group('When the operation is given a non-existing id', () {
            test('Then it throws a state error', () async {
              final operation = validOperation.copyWith(args: {"id": 'block3'});
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<StateError>()));
            });
          });
        });
        group('Given a block with no content list', () {
          group('When no \'after\' arg is provided', () {
            test('Then it inserts the given \'id\' as the only content',
                () async {
              final block1 = BlockTableData(
                  id: 'block1',
                  type: BlockTypeRepo.audio,
                  properties: '{"title":[["title 1"]]}',
                  createdAt: DateTime.utc(1809, DateTime.february, 12),
                  lastEditedAt: DateTime.now());
              final block2 = BlockTableData(
                  id: 'block2',
                  type: BlockTypeRepo.text,
                  properties: '{"title":[["title 2"]]}',
                  createdAt: DateTime.utc(1879, DateTime.march, 14),
                  lastEditedAt: DateTime.now());
              await db.into(db.blockTable).insert(block1);
              await db.into(db.blockTable).insert(block2);

              const operation = Operation(
                  type: OperationType.listAfter,
                  path: ['content'],
                  pointer: (id: 'block1'),
                  args: {"id": 'block2'});
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: const Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.content, '["block2"]');
            });
          });
        });
        group('Given a block with three content items', () {
          setUp(() async {
            final block1 = BlockTableData(
                id: 'block1',
                type: BlockTypeRepo.audio,
                properties: '{"title":[["title 1"]]}',
                content: '["block2","block3","block4"]',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                lastEditedAt: DateTime.now());
            final block5 = BlockTableData(
                id: 'block5',
                type: BlockTypeRepo.text,
                properties: '{"title":[["title 2"]]}',
                createdAt: DateTime.utc(1879, DateTime.march, 14),
                lastEditedAt: DateTime.now());
            await db.into(db.blockTable).insert(block1);
            await db.into(db.blockTable).insert(block5);
          });
          group('When no \'after\' arg is provided', () {
            test('Then it inserts at the end of the content list', () async {
              const operation = Operation(
                  type: OperationType.listAfter,
                  path: ['content'],
                  pointer: (id: 'block1'),
                  args: {"id": 'block5'});
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: const Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.content,
                  '["block2","block3","block4","block5"]');
            });
          });
          group('When \'after\' arg is the first content item', () {
            test('Then it inserts into the second position', () async {
              const operation = Operation(
                  type: OperationType.listAfter,
                  path: ['content'],
                  pointer: (id: 'block1'),
                  args: {"id": 'block5', "after": 'block2'});
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: const Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.content,
                  '["block2","block5","block3","block4"]');
            });
          });
          group('When \'after\' arg is the last content item', () {
            test('Then it inserts at the end of the content list', () async {
              const operation = Operation(
                  type: OperationType.listAfter,
                  path: ['content'],
                  pointer: (id: 'block1'),
                  args: {"id": 'block5', "after": 'block4'});
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: const Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.content,
                  '["block2","block3","block4","block5"]');
            });
          });
          group('When \'after\' arg is not in the content list', () {
            test('Then it inserts at the end of the content list', () async {
              const operation = Operation(
                  type: OperationType.listAfter,
                  path: ['content'],
                  pointer: (id: 'block1'),
                  args: {"id": 'block5', "after": 'blockX'});
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: const Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.content,
                  '["block2","block3","block4","block5"]');
            });
          });
        });
      });
      group('update', () {
        group('Given a block and valid update operation', () {
          late DateTime now;
          final validOperation = Operation(
            type: OperationType.update,
            path: ['external', 'url'],
            pointer: (id: 'block1'),
            args: {
              SingleVal.val.toString(): 'https://example.com',
            },
          );
          setUp(() async {
            now = DateTime.now();
            final block1 = BlockTableData(
                id: 'block1',
                type: BlockTypeRepo.audio,
                properties: '{"title":[["title 1"]]}',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                lastEditedAt: now);
            await db.into(db.blockTable).insert(block1);
          });
          group('When the operation is unmodified', () {
            test('Then the operation executes successfully', () async {
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [validOperation])),
                  returnsNormally);
            });
            test('Then other properties are not overridden', () async {
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [validOperation])),
                  returnsNormally);
              final query = db.select(db.blockTable)
                ..where((tbl) => tbl.id.equals('block1'));
              final block = await query.getSingle();
              expect(block.id, 'block1');
              expect(block.type, BlockTypeRepo.audio);
              expect(block.properties, '{"title":[["title 1"]]}');
              expect(block.external, '{"url":"https://example.com"}');
              expect(block.content, null);
              expect(block.parentId, null);
              expect(
                  block.createdAt, DateTime.utc(1809, DateTime.february, 12));
              expect(block.lastEditedAt, now);
            });
          });
          group('When the operation is given an invalid path', () {
            test('Then it throws a unsupported error', () async {
              final operation = validOperation.copyWith(path: ['properties']);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<UnsupportedError>()));
            });
          });
          group('When the operation is given a non-existing pointer', () {
            test('Then it throws a state error', () async {
              final operation =
                  validOperation.copyWith(pointer: (id: 'blockX'));
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<StateError>()));
            });
          });
        });
        group('Given an \'external\' update operation', () {
          group('And the existing block has no external value', () {
            setUp(() async {
              final block1 = BlockTableData(
                  id: 'block1',
                  type: BlockTypeRepo.audio,
                  properties: '{"title":[["title 1"]]}',
                  createdAt: DateTime.utc(1809, DateTime.february, 12),
                  lastEditedAt: DateTime.now());
              await db.into(db.blockTable).insert(block1);
            });
            test('Then it sets the external url', () async {
              final operation = Operation(
                type: OperationType.update,
                path: ['external', 'url'],
                pointer: (id: 'block1'),
                args: {
                  SingleVal.val.toString(): 'https://example.com',
                },
              );
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.external, '{"url":"https://example.com"}');
            });
          });

          group('And the existing block has an empty external value', () {
            setUp(() async {
              final block1 = BlockTableData(
                  id: 'block1',
                  type: BlockTypeRepo.audio,
                  properties: '{"title":[["title 1"]]}',
                  external: '{}',
                  createdAt: DateTime.utc(1809, DateTime.february, 12),
                  lastEditedAt: DateTime.now());
              await db.into(db.blockTable).insert(block1);
            });
            test('Then it sets the external url', () async {
              final operation = Operation(
                type: OperationType.update,
                path: ['external', 'url'],
                pointer: (id: 'block1'),
                args: {
                  SingleVal.val.toString(): 'https://example.com',
                },
              );
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.external, '{"url":"https://example.com"}');
            });
          });
          group('And the existing block has an existing external url', () {
            setUp(() async {
              final block1 = BlockTableData(
                  id: 'block1',
                  type: BlockTypeRepo.audio,
                  properties: '{"title":[["title 1"]]}',
                  external: '{"url":"https://example.com"}',
                  createdAt: DateTime.utc(1809, DateTime.february, 12),
                  lastEditedAt: DateTime.now());
              await db.into(db.blockTable).insert(block1);
            });
            group('When given a different external url', () {
              test('Then it updates the external url', () async {
                final operation = Operation(
                  type: OperationType.update,
                  path: ['external', 'url'],
                  pointer: (id: 'block1'),
                  args: {
                    SingleVal.val.toString(): 'https://example2.com',
                  },
                );
                final repo = BlockRepo(db);
                await repo.executeTransaction(
                    transaction: Transaction(operations: [operation]));
                final updatedBlock = await (db.select(db.blockTable)
                      ..where((tbl) => tbl.id.equals('block1')))
                    .getSingle();
                expect(updatedBlock.external, '{"url":"https://example2.com"}');
              });
            });
            group('When given an empty external url', () {
              test('Then it sets the external url to null', () async {
                final operation = Operation(
                  type: OperationType.update,
                  path: ['external', 'url'],
                  pointer: (id: 'block1'),
                  args: {
                    SingleVal.val.toString(): '',
                  },
                );
                final repo = BlockRepo(db);
                await repo.executeTransaction(
                    transaction: Transaction(operations: [operation]));
                final updatedBlock = await (db.select(db.blockTable)
                      ..where((tbl) => tbl.id.equals('block1')))
                    .getSingle();
                expect(updatedBlock.external, '{"url":null}');
              });
            });
            group('When given no arg', () {
              test('Then it sets the external url to null', () async {
                const operation = Operation(
                  type: OperationType.update,
                  path: ['external', 'url'],
                  pointer: (id: 'block1'),
                  args: {},
                );
                final repo = BlockRepo(db);
                await repo.executeTransaction(
                    transaction: const Transaction(operations: [operation]));
                final updatedBlock = await (db.select(db.blockTable)
                      ..where((tbl) => tbl.id.equals('block1')))
                    .getSingle();
                expect(updatedBlock.external, '{"url":null}');
              });
            });
          });
          group('And the existing block has a null external url', () {
            setUp(() async {
              final block1 = BlockTableData(
                  id: 'block1',
                  type: BlockTypeRepo.audio,
                  properties: '{"title":[["title 1"]]}',
                  external: '{"url":null}',
                  createdAt: DateTime.utc(1809, DateTime.february, 12),
                  lastEditedAt: DateTime.now());
              await db.into(db.blockTable).insert(block1);
            });
            test('Then it sets the external url', () async {
              final operation = Operation(
                type: OperationType.update,
                path: ['external', 'url'],
                pointer: (id: 'block1'),
                args: {
                  SingleVal.val.toString(): 'https://example.com',
                },
              );
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: Transaction(operations: [operation]));
              final updatedBlock = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(updatedBlock.external, '{"url":"https://example.com"}');
            });
          });
          group('And the existing block has unknown external properties', () {
            final validOperation = Operation(
              type: OperationType.update,
              path: ['external', 'url'],
              pointer: (id: 'block1'),
              args: {
                SingleVal.val.toString(): 'https://example-updated.com',
              },
            );

            setUp(() async {
              final block1 = BlockTableData(
                  id: 'block1',
                  type: BlockTypeRepo.audio,
                  properties: '{"title":[["title 1"]]}',
                  external: '{"url":"https://example.com", "unknown": "value"}',
                  createdAt: DateTime.utc(1809, DateTime.february, 12),
                  lastEditedAt: DateTime.now());
              await db.into(db.blockTable).insert(block1);
            });
            test(
                'Then it persists the external URL without removing the other properties',
                () async {
              // This requirement reduces the chance of accidentally wiping data
              // that isn't yet supported by the frontend but is on the backend.
              //
              // E.g. we might pull a block with external:
              //   {"url": "https://example.com", "other": "value"}
              // from the server. If the client doesn't support "other" we don't
              // want to remove "other" from "external" and then sync "external"
              // to the backend, wiping the "other" property.
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [validOperation])),
                  returnsNormally);
              final query = (db.select(db.blockTable)
                ..where((tbl) => tbl.id.equals('block1')));
              final block = await query.getSingle();
              expect(block.external,
                  '{"url":"https://example-updated.com","unknown":"value"}');
            });
          });
        });
        group('Given a \'lastEditedAt\' update operation', () {
          setUp(() async {
            final block1 = BlockTableData(
                id: 'block1',
                type: BlockTypeRepo.audio,
                properties: '{"title":[["title 1"]]}',
                external: '{"url":"https://example.com", "unknown": "value"}',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                lastEditedAt: DateTime.now());
            await db.into(db.blockTable).insert(block1);
          });
          test('Then it only sets the \'lastEditedAt\' property', () async {
            final operation = Operation(
              type: OperationType.update,
              path: ['lastEditedAt'],
              pointer: (id: 'block1'),
              args: {
                SingleVal.val.toString(): '2021-01-01T00:00:00.000Z',
              },
            );
            final repo = BlockRepo(db);
            await repo.executeTransaction(
                transaction: Transaction(operations: [operation]));
            final updatedBlock = await (db.select(db.blockTable)
                  ..where((tbl) => tbl.id.equals('block1')))
                .getSingle();
            expect(updatedBlock.id, 'block1');
            expect(updatedBlock.type, BlockTypeRepo.audio);
            expect(updatedBlock.properties, '{"title":[["title 1"]]}');
            expect(updatedBlock.external,
                '{"url":"https://example.com", "unknown": "value"}');
            expect(updatedBlock.content, null);
            expect(updatedBlock.parentId, null);
            expect(updatedBlock.createdAt,
                DateTime.utc(1809, DateTime.february, 12));
            expect(updatedBlock.lastEditedAt, DateTime.utc(2021));
          });
        });
      });
      group('set', () {
        group('Given a valid set operation', () {
          final validOperation = Operation(
            type: OperationType.set,
            pointer: (id: 'block1'),
            path: [],
            args: {
              Prop.id.toString(): 'block1',
              Prop.type.toString(): BlockType.audio.toString(),
              Prop.createdAt.toString(): '2021-01-01T00:00:00.000Z',
              Prop.lastEditedAt.toString(): '2021-01-01T00:00:00.000Z',
            },
          );

          group('When the operation is unmodified', () {
            test('Then the operation executes successfully', () {
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [validOperation])),
                  returnsNormally);
            });
          });
          group(
              'When the operation is given an id arg not matching the pointer',
              () {
            test('Then it throws an argument error', () async {
              final operation = validOperation.copyWith(
                  pointer: (id: 'block1'),
                  args: {Prop.id.toString(): 'blockX'});
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<ArgumentError>()));
            });
          });
          group('When the operation is given a non-empty path', () {
            test('Then it throws an unsupported error', () async {
              final operation = validOperation.copyWith(path: ['properties']);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<UnsupportedError>()));
            });
          });
          group('When the operation has it\'s id arg removed', () {
            test('Then it throws a type error', () async {
              final args = Map<String, dynamic>.from(validOperation.args);
              args.remove(Prop.id.toString());

              final operation = validOperation.copyWith(args: args);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<TypeError>()));
            });
          });
          group('When the operation has it\'s type arg removed', () {
            test('Then it throws a type error', () async {
              final args = Map<String, dynamic>.from(validOperation.args);
              args.remove(Prop.type.toString());

              final operation = validOperation.copyWith(args: args);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<TypeError>()));
            });
          });
          group('When the operation is given an unknown type', () {
            test('Then it throws an unsupported error', () async {
              final args = Map<String, dynamic>.from(validOperation.args);
              args[Prop.type.toString()] = 'unknown';

              final operation = validOperation.copyWith(args: args);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<UnsupportedError>()));
            });
          });
          group('When the operation has it\'s createdAt arg removed', () {
            test('Then it throws a type error', () async {
              final args = Map<String, dynamic>.from(validOperation.args);
              args.remove(Prop.createdAt.toString());

              final operation = validOperation.copyWith(args: args);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<TypeError>()));
            });
          });
          group('When the operation has it\'s lastEditedAt arg removed', () {
            test('Then it throws a type error', () async {
              final args = Map<String, dynamic>.from(validOperation.args);
              args.remove(Prop.lastEditedAt.toString());

              final operation = validOperation.copyWith(args: args);
              final repo = BlockRepo(db);
              expect(
                  () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [operation])),
                  throwsA(isA<TypeError>()));
            });
          });
        });
        group('Given a block that already exists', () {
          setUp(() async {
            final block1 = BlockTableData(
                id: 'block1',
                type: BlockTypeRepo.audio,
                properties: '{"title":[["title 1"]]}',
                createdAt: DateTime.utc(1809, DateTime.february, 12),
                lastEditedAt: DateTime.now());
            await db.into(db.blockTable).insert(block1);
          });
          test('Then it returns a state error', () {
            final operation = Operation(
              type: OperationType.set,
              pointer: (id: 'block1'),
              path: [],
              args: {
                Prop.id.toString(): 'block1',
                Prop.type.toString(): BlockType.audio.toString(),
                Prop.createdAt.toString(): '2021-01-01T00:00:00.000Z',
                Prop.lastEditedAt.toString(): '2021-01-01T00:00:00.000Z',
              },
            );
            final repo = BlockRepo(db);
            expect(
                () async => await repo.executeTransaction(
                    transaction: Transaction(operations: [operation])),
                throwsA(isA<StateError>()));
          });
        });
        group('Given an audio block set operation', () {
          group('When it has only the required properties', () {
            test('Then it persists the block', () async {
              final operation = Operation(
                type: OperationType.set,
                pointer: (id: 'block1'),
                path: [],
                args: {
                  Prop.id.toString(): 'block1',
                  Prop.type.toString(): BlockType.audio.toString(),
                  Prop.createdAt.toString(): '2021-01-01T00:00:00.000Z',
                  Prop.lastEditedAt.toString(): '2021-01-01T00:00:00.000Z',
                },
              );
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: Transaction(operations: [operation]));
              final block = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(block.id, 'block1');
              expect(block.type, BlockTypeRepo.audio);
              expect(block.properties, null);
              expect(block.external, null);
              expect(block.content, null);
              expect(block.createdAt, DateTime.utc(2021));
              expect(block.lastEditedAt, DateTime.utc(2021));
            });
          });
          group('When it has all supported properties', () {
            test('Then it persists the block', () async {
              final operation = Operation(
                type: OperationType.set,
                pointer: (id: 'block1'),
                path: [],
                args: {
                  Prop.id.toString(): 'block1',
                  Prop.type.toString(): BlockType.audio.toString(),
                  Prop.properties.toString(): {
                    Property.title.toString(): [
                      ['a title']
                    ],
                    "unsupported": "value"
                  },
                  Prop.external.toString(): {
                    PrepExternal.url.toString(): 'https://example.com',
                    "unsupported": "value"
                  },
                  Prop.content.toString(): ['block2', 'block3', 'block4'],
                  Prop.parentId.toString(): 'block5',
                  Prop.createdAt.toString(): '2021-01-01T00:00:00.000Z',
                  Prop.lastEditedAt.toString(): '2021-01-01T00:00:00.000Z',
                },
              );
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: Transaction(operations: [operation]));
              final block = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(block.id, 'block1');
              expect(block.type, BlockTypeRepo.audio);
              expect(block.properties,
                  '{"title":[["a title"]],"unsupported":"value"}');
              expect(block.external,
                  '{"url":"https://example.com","unsupported":"value"}');
              expect(block.content, '["block2","block3","block4"]');
              expect(block.parentId, 'block5');
              expect(block.createdAt, DateTime.utc(2021));
              expect(block.lastEditedAt, DateTime.utc(2021));
            });
          });
        });
        group('Given a text block set operation', () {
          group('When it has only the required properties', () {
            test('Then it persists the block', () async {
              final operation = Operation(
                type: OperationType.set,
                pointer: (id: 'block1'),
                path: [],
                args: {
                  Prop.id.toString(): 'block1',
                  Prop.type.toString(): BlockType.text.toString(),
                  Prop.createdAt.toString(): '2021-01-01T00:00:00.000Z',
                  Prop.lastEditedAt.toString(): '2021-01-01T00:00:00.000Z',
                },
              );
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: Transaction(operations: [operation]));
              final block = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(block.id, 'block1');
              expect(block.type, BlockTypeRepo.text);
              expect(block.properties, null);
              expect(block.external, null);
              expect(block.content, null);
              expect(block.createdAt, DateTime.utc(2021));
              expect(block.lastEditedAt, DateTime.utc(2021));
            });
          });
          group('When it has all supported properties', () {
            test('Then it persists the block', () async {
              final operation = Operation(
                type: OperationType.set,
                pointer: (id: 'block1'),
                path: [],
                args: {
                  Prop.id.toString(): 'block1',
                  Prop.type.toString(): BlockType.text.toString(),
                  Prop.properties.toString(): {
                    Property.title.toString(): [
                      ['a title']
                    ],
                    "unsupported": "value"
                  },
                  Prop.external.toString(): {
                    PrepExternal.url.toString(): 'https://example.com',
                    "unsupported": "value"
                  },
                  Prop.content.toString(): ['block2', 'block3', 'block4'],
                  Prop.parentId.toString(): 'block5',
                  Prop.createdAt.toString(): '2021-01-01T00:00:00.000Z',
                  Prop.lastEditedAt.toString(): '2021-01-01T00:00:00.000Z',
                },
              );
              final repo = BlockRepo(db);
              await repo.executeTransaction(
                  transaction: Transaction(operations: [operation]));
              final block = await (db.select(db.blockTable)
                    ..where((tbl) => tbl.id.equals('block1')))
                  .getSingle();
              expect(block.id, 'block1');
              expect(block.type, BlockTypeRepo.text);
              expect(block.properties,
                  '{"title":[["a title"]],"unsupported":"value"}');
              expect(block.external,
                  '{"url":"https://example.com","unsupported":"value"}');
              expect(block.content, '["block2","block3","block4"]');
              expect(block.parentId, 'block5');
              expect(block.createdAt, DateTime.utc(2021));
              expect(block.lastEditedAt, DateTime.utc(2021));
            });
          });
        });
      });
      group('Given multiple operations', () {
        test('Then it executes them in order', () async {
          final createOperation = Operation(
            type: OperationType.set,
            pointer: (id: 'block1'),
            path: [],
            args: {
              Prop.id.toString(): 'block1',
              Prop.type.toString(): BlockType.audio.toString(),
              Prop.createdAt.toString(): '2021-01-01T00:00:00.000Z',
              Prop.lastEditedAt.toString(): '2021-01-01T00:00:00.000Z',
            },
          );
          final updateExternalUrlOperationFirst = Operation(
            type: OperationType.update,
            path: ['external', 'url'],
            pointer: (id: 'block1'),
            args: {
              SingleVal.val.toString(): 'https://example.com',
            },
          );
          final updateExternalUrlOperationSecond = Operation(
            type: OperationType.update,
            path: ['external', 'url'],
            pointer: (id: 'block1'),
            args: {
              SingleVal.val.toString(): 'https://example2.com',
            },
          );

          final repo = BlockRepo(db);
          expect(
              () async => await repo.executeTransaction(
                      transaction: Transaction(operations: [
                    createOperation,
                    updateExternalUrlOperationFirst,
                    updateExternalUrlOperationSecond,
                  ])),
              returnsNormally);
          final query = (db.select(db.blockTable)
            ..where((tbl) => tbl.id.equals('block1')));
          final block = await query.getSingle();

          expect(block.external, '{"url":"https://example2.com"}');
        });
      });
      group('Given no operations', () {
        test('Then it does not throw', () {
          expect(
              () async => await BlockRepo(db).executeTransaction(
                  transaction: const Transaction(operations: [])),
              returnsNormally);
        });
      });
    });
  });
}
