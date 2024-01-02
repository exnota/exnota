import 'dart:convert';

import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/execute_transaction_sync_command.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_table.dart';
import 'package:exnota/src/lib/entity_id.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/note/transaction.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mapper.g.dart';

class SyncCommandRepoMapper {
  static SyncCommandTableCompanion toData(SyncCommand command) {
    final logger = Logger(context: 'SyncCommandRepoMapper.toDataInsert');
    switch (command) {
      case ExecuteTransactionSyncCommand():
        final data =
            ExecuteTransactionDataRepo(transaction: command.transaction);
        final id = command.id;
        if (id case EntityWithId()) {
          logger.warn("Command passed with ID. This will be ignored",
              nonPrivateData: {
                'id': id.id,
                'entityId': command.entityId,
                'syncCommand': command.runtimeType,
              });
        }
        return SyncCommandTableCompanion.insert(
            type: SyncCommandRepoType.executeTransaction,
            entityId: command.entityId,
            rootEntityId: command.rootEntityId,
            data: json.encode(data.toJson()),
            status: statusToData(command.status),
            createdAt: command.createdAt,
            updatedAt: command.updatedAt);
      default:
        throw Exception("Unknown command type: ${command.runtimeType}");
    }
  }

  static SyncCommand fromData(SyncCommandTableData commandData) {
    switch (commandData.type) {
      case SyncCommandRepoType.executeTransaction:
        final decoded = jsonDecode(commandData.data);
        final transaction = Transaction.fromJson(decoded["transaction"]);
        return ExecuteTransactionSyncCommand.fromDb(
            id: commandData.id,
            entityId: commandData.entityId,
            rootEntityId: commandData.rootEntityId,
            transaction: transaction,
            status: statusFromData(commandData.status),
            createdAt: commandData.createdAt,
            updatedAt: commandData.updatedAt);
      default:
        throw Exception("Unknown command type: ${commandData.type}");
    }
  }

  static SyncCommandRepoStatus statusToData(SyncCommandStatus status) {
    switch (status) {
      case SyncCommandStatus.waiting:
        return SyncCommandRepoStatus.waiting;
      case SyncCommandStatus.running:
        return SyncCommandRepoStatus.running;
      case SyncCommandStatus.complete:
        return SyncCommandRepoStatus.complete;
      case SyncCommandStatus.error:
        return SyncCommandRepoStatus.error;
    }
  }

  static SyncCommandStatus statusFromData(SyncCommandRepoStatus status) {
    switch (status) {
      case SyncCommandRepoStatus.waiting:
        return SyncCommandStatus.waiting;
      case SyncCommandRepoStatus.running:
        return SyncCommandStatus.running;
      case SyncCommandRepoStatus.complete:
        return SyncCommandStatus.complete;
      case SyncCommandRepoStatus.error:
        return SyncCommandStatus.error;
    }
  }
}

@JsonSerializable()
class ExecuteTransactionDataRepo {
  @JsonKey(name: 'transaction')
  final Transaction transaction;

  ExecuteTransactionDataRepo({required this.transaction});

  factory ExecuteTransactionDataRepo.fromJson(Map<String, dynamic> json) =>
      _$ExecuteTransactionDataRepoFromJson(json);

  Map<String, dynamic> toJson() => _$ExecuteTransactionDataRepoToJson(this);
}
