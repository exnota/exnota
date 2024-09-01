import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_lister.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/block.dart';
import 'package:exnota/src/block/repo/drift/block_repo.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_lister.g.dart';
part 'block_lister.freezed.dart';

enum BlockStatus {
  waiting,
  syncing,
  synced,
  transcribing,
  exported,
  error,
  unknown,
  imported, // Has no local sync command
}

@freezed
class BlockAndStatus with _$BlockAndStatus {
  const factory BlockAndStatus({
    required Block block,
    required BlockStatus status,
  }) = _BlockAndStatus;
}

// Base listers
//
// These fetch directly from the database and, if they are not streaming from
// the database, may need to be refreshed if the database changes.

@riverpod
Stream<List<BlockAndStatus>> blockLister(BlockListerRef ref) {
  final log = ref.watch(loggerProvider('BlockLister'));
  log.debug('Building block lister');

  final syncCommandsAsync = ref.watch(syncCommandListerProvider);
  final List<SyncCommand> syncCommands = [];
  switch (syncCommandsAsync) {
    case AsyncData():
      syncCommands.addAll(syncCommandsAsync.value);
      break;
    case AsyncLoading():
    case AsyncError():
      // No sync commands
      break;
    default:
      throw Exception('Unexpected async state');
  }

  final Map<String, List<SyncCommandStatus>> allSyncStatuses = {};
  for (var command in syncCommands) {
    final blockId = command.entityId;
    if (allSyncStatuses.containsKey(blockId)) {
      allSyncStatuses[blockId]!.add(command.status);
    } else {
      allSyncStatuses[blockId] = [command.status];
    }
  }

  final syncStatuses = allSyncStatuses.map<String, BlockStatus>((key, value) {
    if (value.contains(SyncCommandStatus.error)) {
      return MapEntry(key, BlockStatus.error);
    } else if (value.contains(SyncCommandStatus.waiting)) {
      return MapEntry(key, BlockStatus.waiting);
    } else if (value.contains(SyncCommandStatus.running)) {
      return MapEntry(key, BlockStatus.syncing);
    } else if (value
        .every((element) => element == SyncCommandStatus.complete)) {
      return MapEntry(key, BlockStatus.synced);
    } else {
      log.warn('Unexpected set of statuses for block $key: $value');
      return MapEntry(key, BlockStatus.unknown);
    }
  });

  final userId = ref.watch(activeUserIdOrThrowSyncProvider);
  final blockRepo = ref.watch(blockRepoProvider);
  final blocks = blockRepo.listWatch(userId: userId).map((blocks) {
    return blocks.map((block) {
      BlockStatus status = syncStatuses[block.id] ?? BlockStatus.imported;

      if (status == BlockStatus.synced) {
        if (block.type == BlockType.voiceNote &&
            block.audio?.transcription == null) {
          status = BlockStatus.transcribing;
        } else if (block.external != null) {
          status = BlockStatus.exported;
        }
      }

      return BlockAndStatus(block: block, status: status);
    }).toList();
  });
  return blocks;
}

@riverpod
class Blocks extends _$Blocks {
  @override
  Future<List<Block>> build() async {
    final log = ref.watch(loggerProvider('Blocks'));
    log.debug('Getting blocks');

    final userId = ref.watch(activeUserIdOrThrowSyncProvider);
    final blockRepo = ref.watch(blockRepoProvider);
    final blocks = await blockRepo.list(userId: userId);
    return blocks;
  }

  @Deprecated(
      'Migrate refresh logic to repos. See comment on BlockListerRefresh.')
  void refresh() {
    ref.invalidateSelf();
  }
}

@riverpod
class BlocksWithoutDestination extends _$BlocksWithoutDestination {
  @override
  Future<List<Block>> build() async {
    final log = ref.watch(loggerProvider('BlocksWithoutDestination'));
    log.debug('Getting blocks without destination');

    final userId = ref.watch(activeUserIdOrThrowSyncProvider);
    final blockRepo = ref.watch(blockRepoProvider);
    final blocks = await blockRepo.listWithoutDestination(userId: userId);
    return blocks;
  }

  @Deprecated(
      'Migrate refresh logic to repos. See comment on BlockListerRefresh.')
  void refresh() {
    ref.invalidateSelf();
  }
}

// Derived listers
//
// Don't refresh these directly. Refresh the base listers.

@riverpod
List<Block> blocksLazy(BlocksLazyRef ref) {
  final blocks = ref.watch(blocksProvider).valueOrNull;
  return blocks ?? [];
}

// Helpers

@riverpod
class BlockListerRefresh extends _$BlockListerRefresh {
  @override
  void build() {
    ref.invalidate(blockListerProvider);
  }

  // Refreshes all block lister providers.
  //
  // It feels messy having block importers, etc. refresh the listers directly.
  //
  // A better way to do this might be:
  // - Refactor repos to class-based providers, and create methods on them.
  // - The methods create a class instance of the repos and call them. This
  //   reduces the coupling with providers, but enables notifying in the next
  //   steps. E.g. blockRepoProvider.upsert() creates BlockRepo() and calls
  //   repo.upsert(), where the logic actually is.
  // - Each repo provider method also calls ref.notifyListeners().
  // - This should update every lister provider.
  // - And means that block_importer making repo changes results in block
  //   listers automatically refreshing.
  @Deprecated(
      'Migrate refresh logic to repos. See comment on BlockListerRefresh.')
  void refreshAll() {
    // blockListerProvider streams from the database so shouldn't need to be
    // refreshed.
    ref.read(blocksProvider.notifier).refresh();
    ref.read(blocksWithoutDestinationProvider.notifier).refresh();
  }
}
