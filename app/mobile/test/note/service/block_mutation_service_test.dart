import 'dart:async';

import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/file/local_file.dart';
import 'package:exnota/src/lib/file/service/local_file_mutation_service.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/operation.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:exnota/src/note/repo/id_generator.dart';
import 'package:exnota/src/note/service/block_mutation_service.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks(
    [MockSpec<BlockRepo>(), MockSpec<Clock>(), MockSpec<LocalFileMutator>()])
import 'block_mutation_service_test.mocks.dart';

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
  group('BlockMutationService', () {
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
          final service = container.read(blockMutationServiceProvider.notifier);
          await service.createAudioBlock(extension: 'mp3');

          final expectedCreateOperation =
              Operation(type: OperationType.set, pointer: (
            id: "block id"
          ), path: [], args: {
            BaseArg.id.toString(): "block id",
            BaseArg.type.toString(): BlockType.audio.toString(),
            BaseArg.createdAt.toString():
                DateTime.utc(1809, DateTime.february, 12).toIso8601String(),
            BaseArg.lastEditedAt.toString():
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
          final service = container.read(blockMutationServiceProvider.notifier);
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
          final service = container.read(blockMutationServiceProvider.notifier);
          await service.createAudioBlock(extension: 'mp3');

          verifyZeroInteractions(blockRepo);
          verifyZeroInteractions(localFileMutator);
        });
      });
    });
  });
}
