// import 'package:drift/native.dart';
// import 'package:exnota/src/lib/data/drift/database.dart';
// import 'package:exnota/src/lib/file/local_file.dart';
// import 'package:exnota/src/lib/file/repo/drift/local_file_repo.dart';
// import 'package:exnota/src/lib/file/repo/drift/local_file_table.dart';
// import 'package:flutter_test/flutter_test.dart';

// void main() {
//   late AppDatabase db;

//   setUp(() {
//     db = AppDatabase.inMemory();
//   });

//   tearDown(() async {
//     await db.close();
//   });

//   group('LocalFileRepo', () {
//     group('list', () {
//       group('given no files', () {
//         test('returns empty list', () async {
//           final repo = LocalFileRepo(db);
//           final stream = repo.listWatch();
//           expect(stream, emits([]));
//         });
//       });
//       group('given two files', () {
//         late DateTime now;
//         setUp(() async {
//           now = DateTime.now();
//           final file1 = LocalFileTableData(
//               id: 'file1',
//               entityType: EntityTypeRepo.block,
//               entityId: 'block1',
//               path: 'block1 path',
//               createdAt: DateTime.utc(1879, DateTime.march, 14),
//               syncedAt: null);
//           final file2 = LocalFileTableData(
//               id: 'file2',
//               entityType: EntityTypeRepo.block,
//               entityId: 'block2',
//               path: 'block2 path',
//               createdAt: now,
//               syncedAt: null);
//           await db.into(db.localFileTable).insert(file1);
//           await db.into(db.localFileTable).insert(file2);
//         });
//         test('returns both files with most recently created first', () async {
//           final repo = LocalFileRepo(db);
//           final stream = repo.listWatch().timeout(const Duration(seconds: 30));
//           expectLater(
//               stream,
//               emitsInOrder([
//                 predicate<List<LocalFile>>((files) {
//                   expect(files, hasLength(2));

//                   // First
//                   final file2 = files[0];
//                   expect(file2.id, 'file2');
//                   expect(file2.entityType, EntityType.block);
//                   expect(file2.entityId, 'block2');
//                   expect(file2.path, 'block2 path');
//                   expect(file2.createdAt, now);
//                   expect(file2.syncedAt, null);

//                   // Second
//                   final file = files[1];
//                   expect(file.id, 'file1');
//                   expect(file.entityType, EntityType.block);
//                   expect(file.entityId, 'block1');
//                   expect(file.path, 'block1 path');
//                   expect(
//                       file.createdAt, DateTime.utc(1879, DateTime.march, 14));
//                   expect(file.syncedAt, null);
//                   return true;
//                 }),
//               ]));
//         });
//       });
//     });
//     group('getByEntityId', () {
//       // TODO:
//       group('Given a table with two entities', () {
//         setUp(() async {
//           final file1 = LocalFileTableData(
//               id: 'file1',
//               entityType: EntityTypeRepo.block,
//               entityId: 'block1',
//               path: 'block1 path',
//               createdAt: DateTime.utc(1879, DateTime.march, 14),
//               syncedAt: null);
//           final file2 = LocalFileTableData(
//               id: 'file2',
//               entityType: EntityTypeRepo.block,
//               entityId: 'block2',
//               path: 'block2 path',
//               createdAt: DateTime.now(),
//               syncedAt: null);
//           await db.into(db.localFileTable).insert(file1);
//           await db.into(db.localFileTable).insert(file2);
//         });
//         group('When the requested entity ID is found', () {
//           test('Then the correct entity is returned', () async {
//             final repo = LocalFileRepo(db);
//             final file = await repo.getByEntityId(
//                 entityId: 'block1', entityType: EntityType.block);
//             expect(file, isNotNull);
//             expect(file!.id, 'file1');
//             expect(file.entityType, EntityType.block);
//             expect(file.entityId, 'block1');
//             expect(file.path, 'block1 path');
//             expect(file.createdAt, DateTime.utc(1879, DateTime.march, 14));
//             expect(file.syncedAt, null);
//           });
//         });
//         group('When the requested entity ID is not found', () {
//           test('Then null is returned', () async {
//             final repo = LocalFileRepo(db);
//             final file = await repo.getByEntityId(
//                 entityId: 'block3', entityType: EntityType.block);
//             expect(file, isNull);
//           });
//         });
//         group('When more than one for the requested entity ID is found', () {
//           setUp(() {
//             final file3 = LocalFileTableData(
//                 id: 'file3',
//                 entityType: EntityTypeRepo.block,
//                 entityId: 'block2',
//                 path: 'block3 path',
//                 createdAt: DateTime.now(),
//                 syncedAt: null);
//             db.into(db.localFileTable).insert(file3);
//           });
//           test('Then an error is thrown', () async {
//             final repo = LocalFileRepo(db);
//             expect(
//                 () => repo.getByEntityId(
//                     entityId: 'block2', entityType: EntityType.block),
//                 throwsA(isA<StateError>()));
//           });
//         });
//       });
//     });
//     group('create', () {
//       group('Given a local file', () {
//         test('Then it is created', () async {
//           final repo = LocalFileRepo(db);
//           final file = LocalFile(
//               id: 'file1',
//               entityType: EntityType.block,
//               entityId: 'block1',
//               path: 'block1 path',
//               createdAt: DateTime.utc(1879, DateTime.march, 14),
//               syncedAt: null);
//           await repo.create(file: file);
//           final result = await (db.select(db.localFileTable)
//                 ..where((t) => t.id.equals('file1')))
//               .getSingleOrNull();
//           expect(result, isNotNull);
//           expect(result!.id, 'file1');
//           expect(result.entityType, EntityTypeRepo.block);
//           expect(result.entityId, 'block1');
//           expect(result.path, 'block1 path');
//           expect(result.createdAt, DateTime.utc(1879, DateTime.march, 14));
//           expect(result.syncedAt, null);
//         });

//         group('When the path already exists', () {
//           setUp(() async {
//             final file1 = LocalFileTableData(
//                 id: 'file1',
//                 entityType: EntityTypeRepo.block,
//                 entityId: 'block1',
//                 path: 'block1 path',
//                 createdAt: DateTime.utc(1879, DateTime.march, 14),
//                 syncedAt: null);
//             await db.into(db.localFileTable).insert(file1);
//           });
//           test('Then when creating an error is thrown', () async {
//             final repo = LocalFileRepo(db);
//             final file2 = LocalFile(
//                 id: 'file2',
//                 entityType: EntityType.block,
//                 entityId: 'block2',
//                 path: 'block1 path',
//                 createdAt: DateTime.now(),
//                 syncedAt: null);
//             expect(() => repo.create(file: file2),
//                 throwsA(isA<SqliteException>()));
//           });
//         });
//       });
//     });
//   });
// }
