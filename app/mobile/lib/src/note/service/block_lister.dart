import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/data/sync/service/sync_command_lister.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
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
}

@freezed
class BlockAndStatus with _$BlockAndStatus {
  const factory BlockAndStatus({
    required Block block,
    required BlockStatus status,
  }) = _BlockAndStatus;
}

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
      BlockStatus status = syncStatuses[block.id] ?? BlockStatus.unknown;

      if (status == BlockStatus.synced) {
        if (block.type == BlockType.audio &&
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
