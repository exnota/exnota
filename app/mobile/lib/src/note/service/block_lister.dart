import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/block.dart';
import 'package:exnota/src/note/repo/drift/block_repo.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_lister.g.dart';
part 'block_lister.freezed.dart';

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

  // final syncCommandsAsync = ref.watch(syncCommandListerProvider);
  // final List<SyncCommand> syncCommands = [];
  // switch (syncCommandsAsync) {
  //   case AsyncData():
  //     syncCommands.addAll(syncCommandsAsync.value);
  //     break;
  //   case AsyncLoading():
  //   case AsyncError():
  //     // No sync commands
  //     break;
  //   default:
  //     throw Exception('Unexpected async state');
  // }

  // final Map<String, List<SyncCommandStatus>> allStatuses = {};
  // for (var command in syncCommands) {
  //   final blockId = command.entityId;
  //   if (allStatuses.containsKey(blockId)) {
  //     allStatuses[blockId]!.add(command.status);
  //   } else {
  //     allStatuses[blockId] = [command.status];
  //   }
  // }

  // final statuses = allStatuses.map<String, BlockStatus>((key, value) {
  //   if (value.contains(SyncCommandStatus.error)) {
  //     return MapEntry(key, BlockStatus.error);
  //   } else if (value.contains(SyncCommandStatus.running) ||
  //       value.contains(SyncCommandStatus.waiting)) {
  //     return MapEntry(key, BlockStatus.exporting);
  //   } else if (value
  //       .every((element) => element == SyncCommandStatus.complete)) {
  //     return MapEntry(key, BlockStatus.exported);
  //   } else {
  //     logger.warn('Unexpected set of statuses for block $key: $value');
  //     return MapEntry(key, BlockStatus.unknown);
  //   }
  // });

  final userId = ref.watch(activeUserIdOrThrowProvider);
  final blockRepo = ref.watch(blockRepoProvider);
  final blocks = blockRepo.listWatch(userId: userId).map((blocks) {
    return blocks.map((block) {
      // TODO: Add status
      return BlockAndStatus(block: block, status: BlockStatus.unknown);
    }).toList();
  });
  return blocks;
}

enum BlockStatus {
  exporting,
  exported,
  error,
  unknown,
}
