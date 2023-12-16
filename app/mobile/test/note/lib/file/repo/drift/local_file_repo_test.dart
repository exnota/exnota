import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_repo.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalFileRepo', () {
    group('list', () {
      group('given no files', () {
        test('returns empty list', () async {
          final repo = LocalFileRepo(db);
          final stream = repo.listWatch();
          expect(stream, emits([]));
        });
      });
      group('given two files', () {
        late DateTime now;
        setUp(() async {
          now = DateTime.now();
          final file1 = LocalFileTableData(
              id: 'file1',
              entityType: EntityTypeRepo.block,
              entityId: 'block1',
              path: 'a path',
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              syncedAt: null);
          final file2 = LocalFileTableData(
              id: 'file2',
              entityType: EntityTypeRepo.block,
              entityId: 'block2',
              path: 'a path',
              createdAt: now,
              syncedAt: null);
          await db.into(db.localFileTable).insert(file1);
          await db.into(db.localFileTable).insert(file2);
        });
        test('returns both files with most recently created first', () async {
          final repo = LocalFileRepo(db);
          final stream = repo.listWatch().timeout(const Duration(seconds: 30));
          expectLater(
              stream,
              emitsInOrder([
                predicate<List<LocalFile>>((files) {
                  expect(files, hasLength(2));

                  // First
                  final file2 = files[0];
                  expect(file2.id, 'file2');
                  expect(file2.entityType, EntityType.block);
                  expect(file2.entityId, 'block2');
                  expect(file2.path, 'a path');
                  expect(file2.createdAt, now);
                  expect(file2.syncedAt, null);

                  // Second
                  final file = files[1];
                  expect(file.id, 'file1');
                  expect(file.entityType, EntityType.block);
                  expect(file.entityId, 'block1');
                  expect(file.path, 'a path');
                  expect(
                      file.createdAt, DateTime.utc(1879, DateTime.march, 14));
                  expect(file.syncedAt, null);
                  return true;
                }),
              ]));
        });
      });
    });
  });
}
