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
      // TODO:
      // - update
      //   -error if block doesn't exist
      //   - error if path not supported
      //   - handles update external.url
      //     - from no value to value
      //     - from value to another value
      //     - from value to no value
      // - set
      //   - error if block exists
      //   - error if pointer doesn't match id
      //   - error if path not empty
      //   - error if id not provided
      //   - error if type not provided
      //   - error if createdAt not provided
      //   - error if lastEditedAt not provided
      //   - correctly persists required values
      //   - correctly persists optional values
      // - multiple ops
      //   - realistic example
      // - single ops
      //   - realistic example
      // - no ops
    });
  });
}
