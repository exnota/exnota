import 'package:exnota/src/lib/data/sync/execute_transaction_sync_command.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_lister.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:exnota/src/note/service/block_lister.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<BlockRepo>()])
import 'block_lister_test.mocks.dart';

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
  group('BlockLister', () {
    group('Given a block with an errored sync command', () {
      test('Then the lister returns the block with an errored status',
          () async {
        final blockRepo = MockBlockRepo();
        when(blockRepo.listWatch()).thenAnswer((_) {
          return Stream.value([
            Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
          ]);
        });

        // DO NOT share ProviderContainers between tests.
        final container = createContainer(
          overrides: [
            blockRepoProvider.overrideWith((ref) {
              return blockRepo;
            }),
            syncCommandListerProvider.overrideWith((ref) {
              return Stream<List<SyncCommand<dynamic>>>.value([
                ExecuteTransactionSyncCommand.fromDb(
                    id: 1,
                    entityId: 'block1',
                    status: SyncCommandStatus.complete,
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 2,
                    entityId: 'block1',
                    status: SyncCommandStatus.error,
                    transaction: const Transaction(operations: [])),
              ]);
            }),
          ],
        );

        // This is needed to prevent blockListerProvider being auto-disposed
        // before the test finishes running. I tried to replace the
        // container.read() call with this, but it didn't work.
        container.listen(blockListerProvider, (_, __) {});

        final expected = [
          BlockAndStatus(
            block: Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
            status: BlockStatus.error,
          ),
        ];
        await expectLater(
          container.read(blockListerProvider.future),
          completion(equals(expected)),
        );
      });
    });
    group('Given a block with a running sync command, and no errored', () {
      test('Then the lister returns the block with an exporting status',
          () async {
        final blockRepo = MockBlockRepo();
        when(blockRepo.listWatch()).thenAnswer((_) {
          return Stream.value([
            Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
          ]);
        });

        // DO NOT share ProviderContainers between tests.
        final container = createContainer(
          overrides: [
            blockRepoProvider.overrideWith((ref) {
              return blockRepo;
            }),
            syncCommandListerProvider.overrideWith((ref) {
              return Stream<List<SyncCommand<dynamic>>>.value([
                ExecuteTransactionSyncCommand.fromDb(
                    id: 1,
                    entityId: 'block1',
                    status: SyncCommandStatus.running,
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 2,
                    entityId: 'block1',
                    status: SyncCommandStatus.complete,
                    transaction: const Transaction(operations: [])),
              ]);
            }),
          ],
        );

        // This is needed to prevent blockListerProvider being auto-disposed
        // before the test finishes running. I tried to replace the
        // container.read() call with this, but it didn't work.
        container.listen(blockListerProvider, (_, __) {});

        final expected = [
          BlockAndStatus(
            block: Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
            status: BlockStatus.exporting,
          ),
        ];
        await expectLater(
          container.read(blockListerProvider.future),
          completion(equals(expected)),
        );
      });
    });
    group(
        'Given a block with a waiting sync command, and no errored or running',
        () {
      test('Then the lister returns the block with an exporting status',
          () async {
        final blockRepo = MockBlockRepo();
        when(blockRepo.listWatch()).thenAnswer((_) {
          return Stream.value([
            Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
          ]);
        });

        // DO NOT share ProviderContainers between tests.
        final container = createContainer(
          overrides: [
            blockRepoProvider.overrideWith((ref) {
              return blockRepo;
            }),
            syncCommandListerProvider.overrideWith((ref) {
              return Stream<List<SyncCommand<dynamic>>>.value([
                ExecuteTransactionSyncCommand.fromDb(
                    id: 1,
                    entityId: 'block1',
                    status: SyncCommandStatus.complete,
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 2,
                    entityId: 'block1',
                    status: SyncCommandStatus.waiting,
                    transaction: const Transaction(operations: [])),
              ]);
            }),
          ],
        );

        // This is needed to prevent blockListerProvider being auto-disposed
        // before the test finishes running. I tried to replace the
        // container.read() call with this, but it didn't work.
        container.listen(blockListerProvider, (_, __) {});

        final expected = [
          BlockAndStatus(
            block: Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
            status: BlockStatus.exporting,
          ),
        ];
        await expectLater(
          container.read(blockListerProvider.future),
          completion(equals(expected)),
        );
      });
    });
    group(
        'Given a block with a complete sync command, and no errored, running, or waiting',
        () {
      test('Then the lister returns the block with an exported status',
          () async {
        final blockRepo = MockBlockRepo();
        when(blockRepo.listWatch()).thenAnswer((_) {
          return Stream.value([
            Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
          ]);
        });

        // DO NOT share ProviderContainers between tests.
        final container = createContainer(
          overrides: [
            blockRepoProvider.overrideWith((ref) {
              return blockRepo;
            }),
            syncCommandListerProvider.overrideWith((ref) {
              return Stream<List<SyncCommand<dynamic>>>.value([
                ExecuteTransactionSyncCommand.fromDb(
                    id: 1,
                    entityId: 'block1',
                    status: SyncCommandStatus.complete,
                    transaction: const Transaction(operations: [])),
                ExecuteTransactionSyncCommand.fromDb(
                    id: 2,
                    entityId: 'block1',
                    status: SyncCommandStatus.complete,
                    transaction: const Transaction(operations: [])),
              ]);
            }),
          ],
        );

        // This is needed to prevent blockListerProvider being auto-disposed
        // before the test finishes running. I tried to replace the
        // container.read() call with this, but it didn't work.
        container.listen(blockListerProvider, (_, __) {});

        final expected = [
          BlockAndStatus(
            block: Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
            status: BlockStatus.exported,
          ),
        ];
        await expectLater(
          container.read(blockListerProvider.future),
          completion(equals(expected)),
        );
      });
    });
    group('Given a block with no sync commands', () {
      test('Then the lister returns the block with an unknown status',
          () async {
        final blockRepo = MockBlockRepo();
        when(blockRepo.listWatch()).thenAnswer((_) {
          return Stream.value([
            Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
          ]);
        });

        // DO NOT share ProviderContainers between tests.
        final container = createContainer(
          overrides: [
            blockRepoProvider.overrideWith((ref) {
              return blockRepo;
            }),
            syncCommandListerProvider.overrideWith((ref) {
              return Stream<List<SyncCommand<dynamic>>>.value([]);
            }),
          ],
        );

        // This is needed to prevent blockListerProvider being auto-disposed
        // before the test finishes running. I tried to replace the
        // container.read() call with this, but it didn't work.
        container.listen(blockListerProvider, (_, __) {});

        final expected = [
          BlockAndStatus(
            block: Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
            status: BlockStatus.unknown,
          ),
        ];
        await expectLater(
          container.read(blockListerProvider.future),
          completion(equals(expected)),
        );
      });
    });
    group('Given multiple persisted blocks with varying sync command statuses',
        () {
      test('Then the lister returns only root blocks', () async {
        // TODO:
      });
      test('Then the lister returns the expected blocks and statuses',
          () async {
        final blockRepo = MockBlockRepo();
        when(blockRepo.listWatch()).thenAnswer((_) {
          return Stream.value([
            Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
            Block(
              id: 'block2',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 2 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              lastEditedAt: DateTime.utc(1809, DateTime.february, 12),
            ),
          ]);
        });
        final Stream<List<SyncCommand<dynamic>>> commandStream = Stream.value(
          [
            ExecuteTransactionSyncCommand.fromDb(
                id: 1,
                entityId: 'block1',
                status: SyncCommandStatus.complete,
                transaction: const Transaction(operations: [])),
            ExecuteTransactionSyncCommand.fromDb(
                id: 2,
                entityId: 'block2',
                status: SyncCommandStatus.error,
                transaction: const Transaction(operations: [])),
          ],
        );

        // DO NOT share ProviderContainers between tests.
        final container = createContainer(
          overrides: [
            blockRepoProvider.overrideWith((ref) {
              return blockRepo;
            }),
            syncCommandListerProvider.overrideWith((ref) {
              return commandStream;
            }),
          ],
        );

        // This is needed to prevent blockListerProvider being auto-disposed
        // before the test finishes running. I tried to replace the
        // container.read() call with this, but it didn't work.
        container.listen(blockListerProvider, (_, __) {});

        final expected = [
          BlockAndStatus(
            block: Block(
              id: 'block1',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 1 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1879, DateTime.march, 14),
              lastEditedAt: DateTime.utc(1879, DateTime.march, 14),
            ),
            status: BlockStatus.exported,
          ),
          BlockAndStatus(
            block: Block(
              id: 'block2',
              type: BlockType.text,
              properties: {
                Property.title.toString(): [
                  ['Block 2 title']
                ]
              },
              external: null,
              content: null,
              parentId: null,
              createdAt: DateTime.utc(1809, DateTime.february, 12),
              lastEditedAt: DateTime.utc(1809, DateTime.february, 12),
            ),
            status: BlockStatus.error,
          ),
        ];
        await expectLater(
          container.read(blockListerProvider.future),
          completion(equals(expected)),
        );
      });
    });
  });
}
