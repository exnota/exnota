import 'dart:async';

import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/service/local_file_mutation_service.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/operation.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:exnota/src/note/service/block_mutator.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks(
    [MockSpec<BlockRepo>(), MockSpec<Clock>(), MockSpec<LocalFileMutator>()])
import 'block_mutator_test.mocks.dart';

ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  addTearDown(container.dispose);

  return container;
}

void main() {
  group('BlockMutator', () {
    group('createAudioBlock', () {
      group('When called', () {
        test('Then it sends a create operation to the repo', () async {
          final repo = MockBlockRepo();

          // DO NOT share ProviderContainers between tests.
          final container = createContainer(
            overrides: [
              transactionProvider.overrideWith(
                (ref) {
                  Future<String> dbTransactionMock<String>(
                      Future<String> Function() arg,
                      {bool requireNew = false}) {
                    return arg();
                  }

                  return dbTransactionMock;
                },
              ),
              blockRepoProvider.overrideWith((ref) {
                return repo;
              }),
              localFileMutatorProvider.overrideWith((ref) {
                return MockLocalFileMutator();
              }),
              idGeneratorProvider.overrideWith((ref) {
                return () => 'block id';
              }),
              clockProvider.overrideWith((ref) {
                final mock = MockClock();
                when(mock.now())
                    .thenReturn(DateTime.utc(1809, DateTime.february, 12));
                return mock;
              }),
            ],
          );
          final service = container.read(blockMutatorProvider.notifier);
          await service.createAudioBlock(extension: 'mp3');

          final expectedCreateOperation =
              Operation(type: OperationType.set, pointer: (
            id: "block id"
          ), path: [], args: {
            Prop.id.toString(): "block id",
            Prop.type.toString(): BlockType.audio.toString(),
            Prop.createdAt.toString():
                DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
            Prop.lastEditedAt.toString():
                DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
          });
          final expectedTransaction =
              Transaction(operations: [expectedCreateOperation]);
          expect(
              verify(repo.executeTransaction(
                      transaction: captureAnyNamed("transaction")))
                  .captured
                  .first,
              equals(expectedTransaction));
        });
        test(
            'Then it creates a file using the local file service and returns it',
            () async {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(
            overrides: [
              transactionProvider.overrideWith(
                (ref) {
                  Future<String> dbTransactionMock<String>(
                      Future<String> Function() arg,
                      {bool requireNew = false}) {
                    return arg();
                  }

                  return dbTransactionMock;
                },
              ),
              blockRepoProvider.overrideWith((ref) {
                return MockBlockRepo();
              }),
              localFileMutatorProvider.overrideWith((ref) {
                final mock = MockLocalFileMutator();
                when(
                  mock.createForAudioBlock(
                    blockId: argThat(equals('block id'), named: 'blockId'),
                    extension: argThat(equals('mp3'), named: 'extension'),
                    createdAt: argThat(
                        equals(DateTime.utc(
                            1809, DateTime.february, 12, 0, 0, 0, 0)),
                        named: 'createdAt'),
                  ),
                ).thenAnswer(
                  (_) => Future.value(
                    LocalFile(
                        id: 'local file id',
                        entityType: EntityType.block,
                        entityId: 'block id',
                        path: 'some-path',
                        createdAt: DateTime.utc(1809, DateTime.february, 12),
                        syncedAt: null),
                  ),
                );
                return mock;
              }),
              idGeneratorProvider.overrideWith((ref) {
                return () => 'block id';
              }),
              clockProvider.overrideWith((ref) {
                final mock = MockClock();
                when(mock.now())
                    .thenReturn(DateTime.utc(1809, DateTime.february, 12));
                return mock;
              }),
            ],
          );
          final service = container.read(blockMutatorProvider.notifier);
          final actualFile = await service.createAudioBlock(extension: 'mp3');

          final expectedFile = LocalFile(
              id: 'local file id',
              entityType: EntityType.block,
              entityId: 'block id',
              path: 'some-path',
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              syncedAt: null);
          expect(actualFile, equals(expectedFile));
        });
        test(
            'Then if the transaction isn\'t executed, the local file service '
            'and block repo file are not called', () async {
          final blockRepo = MockBlockRepo();
          final localFileMutator = MockLocalFileMutator();

          final container = createContainer(
            overrides: [
              transactionProvider.overrideWith(
                (ref) {
                  Future<T> dbTransactionMock<T>(Future<T> Function() arg,
                      {bool requireNew = false}) {
                    // Instead of calling arg(), return a dummy local file
                    // future.
                    final completer = Completer<LocalFile>();
                    final localFile = LocalFile(
                        id: 'local file id',
                        entityType: EntityType.block,
                        entityId: 'block id',
                        path: 'some-path',
                        createdAt: DateTime.utc(1809, DateTime.february, 12),
                        syncedAt: null);

                    completer.complete(localFile);
                    return completer.future as Future<T>;
                  }

                  return dbTransactionMock;
                },
              ),
              blockRepoProvider.overrideWith((ref) {
                return blockRepo;
              }),
              localFileMutatorProvider.overrideWith((ref) {
                return localFileMutator;
              }),
              idGeneratorProvider.overrideWith((ref) {
                return () => 'block id';
              }),
              clockProvider.overrideWith((ref) {
                final mock = MockClock();
                when(mock.now())
                    .thenReturn(DateTime.utc(1809, DateTime.february, 12));
                return mock;
              }),
            ],
          );
          final service = container.read(blockMutatorProvider.notifier);
          await service.createAudioBlock(extension: 'mp3');

          verifyZeroInteractions(blockRepo);
          verifyZeroInteractions(localFileMutator);
        });
      });
    });
    group('setAudioBlockData', () {
      group('When called with 2 blocks of transcriptions', () {
        test('Then it creates the expected operations in order', () async {
          final repo = MockBlockRepo();
          num childId = 0;

          // DO NOT share ProviderContainers between tests.
          final container = createContainer(
            overrides: [
              transactionProvider.overrideWith(
                (ref) {
                  Future<String> dbTransactionMock<String>(
                      Future<String> Function() arg,
                      {bool requireNew = false}) {
                    return arg();
                  }

                  return dbTransactionMock;
                },
              ),
              blockRepoProvider.overrideWith((ref) {
                return repo;
              }),
              idGeneratorProvider.overrideWith((ref) {
                return () => 'child id ${childId++}';
              }),
              clockProvider.overrideWith((ref) {
                final mock = MockClock();
                when(mock.now())
                    .thenReturn(DateTime.utc(1809, DateTime.february, 12));
                return mock;
              }),
            ],
          );

          final expectedChild1Create = Operation(
            type: OperationType.set,
            pointer: (id: 'child id 0'),
            path: [],
            args: {
              Prop.id.toString(): 'child id 0',
              Prop.type.toString(): BlockType.text.toString(),
              Prop.properties.toString(): {
                Property.title.toString(): [
                  ['paragraph 1']
                ]
              },
              Prop.parentId.toString(): 'block id',
              Prop.createdAt.toString():
                  DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
              Prop.lastEditedAt.toString():
                  DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
            },
          );
          final expectedChild2Create = Operation(
            type: OperationType.set,
            pointer: (id: 'child id 1'),
            path: [],
            args: {
              Prop.id.toString(): 'child id 1',
              Prop.type.toString(): BlockType.text.toString(),
              Prop.properties.toString(): {
                Property.title.toString(): [
                  ['paragraph 2']
                ]
              },
              Prop.parentId.toString(): 'block id',
              Prop.createdAt.toString():
                  DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
              Prop.lastEditedAt.toString():
                  DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
            },
          );
          final expectedlistAfterChild1 = Operation(
            type: OperationType.listAfter,
            pointer: (id: 'block id'),
            path: [Prop.content.toString()],
            args: {
              ListAfterArg.id.toString(): 'child id 0',
            },
          );
          final expectedlistAfterChild2 = Operation(
            type: OperationType.listAfter,
            pointer: (id: 'block id'),
            path: [Prop.content.toString()],
            args: {
              ListAfterArg.id.toString(): 'child id 1',
            },
          );
          final expectedUpdateTitle = Operation(
            type: OperationType.update,
            pointer: (id: 'block id'),
            path: [Prop.properties.toString(), Property.title.toString()],
            args: {
              SingleVal.val.toString(): [
                ['paragraph 1']
              ],
            },
          );
          final expectedUpdateUrl = Operation(
            type: OperationType.update,
            pointer: (id: 'block id'),
            path: [Prop.external.toString(), PrepExternal.url.toString()],
            args: {
              SingleVal.val.toString(): 'external url',
            },
          );
          final expectedUpdateEditedAt = Operation(
            type: OperationType.update,
            pointer: (id: 'block id'),
            path: [Prop.lastEditedAt.toString()],
            args: {
              SingleVal.val.toString():
                  DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
            },
          );
          final expectedTransaction = Transaction(operations: [
            expectedChild1Create,
            expectedChild2Create,
            expectedlistAfterChild1,
            expectedlistAfterChild2,
            expectedUpdateTitle,
            expectedUpdateUrl,
            expectedUpdateEditedAt
          ]);

          final service = container.read(blockMutatorProvider.notifier);
          await service.setAudioBlockData(
            blockId: 'block id',
            transcription: ['paragraph 1', 'paragraph 2'],
            externalUrl: 'external url',
          );

          expect(
              verify(repo.executeTransaction(
                      transaction: captureAnyNamed("transaction")))
                  .captured
                  .first,
              equals(expectedTransaction));
        });
      });
    });
  });
}
