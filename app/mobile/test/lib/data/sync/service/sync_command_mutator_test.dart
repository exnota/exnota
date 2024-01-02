import 'package:exnota/src/lib/clock.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/execute_transaction_sync_command.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_mutator.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SyncCommandRepo>(), MockSpec<Clock>()])
import 'sync_command_mutator_test.mocks.dart';

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
  group('SyncCommandMutator', () {
    group('retryForRootEntity', () {
      group('Given a block with no sync commands', () {
        test('Then it should not update any statuses', () {
          final repo = MockSyncCommandRepo();
          when(repo.fetchByRootEntityId('block id'))
              .thenAnswer((_) async => []);

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
              syncCommandRepoProvider.overrideWithValue(
                repo,
              ),
              clockProvider.overrideWith((ref) {
                final mock = MockClock();
                when(mock.now()).thenReturn(DateTime.utc(2001));
                return mock;
              }),
            ],
          );
          final service = container.read(syncCommandMutatorProvider.notifier);

          expect(service.retryForRootEntity(id: 'root'), completion(null));
          verifyNever(repo.setStatus(
              id: anyNamed('id'),
              status: anyNamed('status'),
              updatedAt: anyNamed('updatedAt')));
        });
      });
      group(
          'Given a block with no errored sync commands for it or its children',
          () {
        // TODO:
        test('Then it should not update any statuses', () {
          final repo = MockSyncCommandRepo();
          when(repo.fetchByRootEntityId('block id')).thenAnswer((_) async => [
                ExecuteTransactionSyncCommand.fromDb(
                    id: 1,
                    entityId: 'block id',
                    rootEntityId: 'block id',
                    status: SyncCommandStatus.complete,
                    updatedAt: DateTime.utc(1809, DateTime.february, 12),
                    createdAt: DateTime.utc(1809, DateTime.february, 12),
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 2,
                    entityId: 'child id',
                    rootEntityId: 'block id',
                    status: SyncCommandStatus.running,
                    updatedAt: DateTime.utc(1809, DateTime.february, 12),
                    createdAt: DateTime.utc(1809, DateTime.february, 12),
                    transaction: const Transaction(operations: [])),
              ]);

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
              syncCommandRepoProvider.overrideWithValue(
                repo,
              ),
              clockProvider.overrideWith((ref) {
                final mock = MockClock();
                when(mock.now()).thenReturn(DateTime.utc(2001));
                return mock;
              }),
            ],
          );
          final service = container.read(syncCommandMutatorProvider.notifier);

          expect(service.retryForRootEntity(id: 'root'), completion(null));
          verifyNever(repo.setStatus(
              id: anyNamed('id'),
              status: anyNamed('status'),
              updatedAt: anyNamed('updatedAt')));
        });
      });
      group(
          'Given a block that has an errored sync command for itself and a child',
          () {
        test(
            'Then it should set the status of only the errored sync commands to \'waiting\'',
            () async {
          final repo = MockSyncCommandRepo();
          when(repo.fetchByRootEntityId('block id')).thenAnswer((_) async => [
                ExecuteTransactionSyncCommand.fromDb(
                    id: 1,
                    entityId: 'block id',
                    rootEntityId: 'block id',
                    status: SyncCommandStatus.error,
                    updatedAt: DateTime.utc(1809, DateTime.february, 12),
                    createdAt: DateTime.utc(1809, DateTime.february, 12),
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 2,
                    entityId: 'block id',
                    rootEntityId: 'block id',
                    status: SyncCommandStatus.running,
                    updatedAt: DateTime.utc(1809, DateTime.february, 12),
                    createdAt: DateTime.utc(1809, DateTime.february, 12),
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 3,
                    entityId: 'child id',
                    rootEntityId: 'block id',
                    status: SyncCommandStatus.error,
                    updatedAt: DateTime.utc(1809, DateTime.february, 12),
                    createdAt: DateTime.utc(1809, DateTime.february, 12),
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 4,
                    entityId: 'child id',
                    rootEntityId: 'block id',
                    status: SyncCommandStatus.running,
                    updatedAt: DateTime.utc(1809, DateTime.february, 12),
                    createdAt: DateTime.utc(1809, DateTime.february, 12),
                    transaction: const Transaction(operations: [])),
              ]);

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
              syncCommandRepoProvider.overrideWithValue(
                repo,
              ),
              clockProvider.overrideWith((ref) {
                final mock = MockClock();
                when(mock.now()).thenReturn(DateTime.utc(2001));
                return mock;
              }),
            ],
          );
          final service = container.read(syncCommandMutatorProvider.notifier);

          await service.retryForRootEntity(id: 'block id');
          verify(repo.fetchByRootEntityId(any)).called(1);
          verify(repo.setStatus(
                  id: 1,
                  status: SyncCommandStatus.waiting,
                  updatedAt: DateTime.utc(2001)))
              .called(1);
          verify(repo.setStatus(
              id: 3,
              status: SyncCommandStatus.waiting,
              updatedAt: DateTime.utc(2001)));
          verifyNoMoreInteractions(repo);
        });
      });
    });
  });
}
