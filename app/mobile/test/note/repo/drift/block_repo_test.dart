import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/block/block.dart';
import 'package:exnota/src/block/repo/drift/block_repo.dart';
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
        test('then it returns empty list', () async {
          final repo = BlockRepo(db);
          final stream = repo.listWatch(userId: 'user 1');
          expect(stream, emits([]));
        });
      });
      group('given three blocks, where two are for user 1', () {
        late DateTime now;
        setUp(() async {
          now = Clock().now();
          final block1 = BlockTableData(
              id: 'block1',
              type: 'voice-note',
              user: 'user 1',
              userCreated: DateTime.utc(1809, DateTime.february, 11),
              created: DateTime.utc(1809, DateTime.february, 12),
              updated: now);
          final block2 = BlockTableData(
              id: 'block2',
              type: 'voice-note',
              user: 'user 1',
              userCreated: DateTime.utc(1879, DateTime.march, 13),
              created: DateTime.utc(1879, DateTime.march, 14),
              updated: now);
          final block3 = BlockTableData(
              id: 'block3',
              type: 'voice-note',
              user: 'user 2',
              userCreated: DateTime.utc(1879, DateTime.march, 13),
              created: DateTime.utc(1879, DateTime.march, 14),
              updated: now);
          await db.into(db.blockTable).insert(block1);
          await db.into(db.blockTable).insert(block2);
          await db.into(db.blockTable).insert(block3);
        });
        group('When list is called for user 1', () {
          test(
              'Then it returns user 1\'s two blocks with most recently created first',
              () async {
            final repo = BlockRepo(db);
            final stream = repo.listWatch(userId: 'user 1');
            await expectLater(
                stream,
                emitsInOrder([
                  predicate<List<Block>>((blocks) {
                    expect(blocks, hasLength(2));

                    // First
                    final block = blocks[0];
                    expect(block.id, 'block2');
                    expect(block.type, BlockType.voiceNote);
                    expect(block.userId, 'user 1');
                    expect(block.userCreated,
                        DateTime.utc(1879, DateTime.march, 13));
                    expect(
                        block.created, DateTime.utc(1879, DateTime.march, 14));
                    expect(block.updated, now);

                    // Second
                    final block2 = blocks[1];
                    expect(block2.id, 'block1');
                    expect(block2.type, BlockType.voiceNote);
                    expect(block2.userId, 'user 1');
                    expect(block2.userCreated,
                        DateTime.utc(1809, DateTime.february, 11));
                    expect(block2.created,
                        DateTime.utc(1809, DateTime.february, 12));
                    expect(block2.updated, now);

                    return true;
                  }),
                ]));
          });
        });
      });
    });
    // group('create', () {
    //   test('persists the given block', () async {
    //     final repo = BlockRepo(db);
    //     final now = Clock().now();
    //     final input = Block(
    //         id: 'block id',
    //         type: BlockType.audio,
    //         properties: {
    //           Property.title.toString(): [
    //             ['a title']
    //           ]
    //         },
    //         createdAt: now,
    //         lastEditedAt: now);
    //     await repo.create(block: input);
    //     final output = await db.select(db.blockTable).getSingle();
    //     expect(output.id, input.id);
    //     expect(output.type, BlockTypeRepo.audio);
    //     expect(output.properties, '{"title":[["a title"]]}');
    //     expect(output.createdAt, input.createdAt);
    //     expect(output.lastEditedAt, input.lastEditedAt);
    //   });
    // });
  });
}
