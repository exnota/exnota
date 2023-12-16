import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';
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
  });
}
