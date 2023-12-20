import 'package:freezed_annotation/freezed_annotation.dart';

part 'operation.freezed.dart';

@freezed
class Operation with _$Operation {
  const factory Operation({
    required OperationType type,
    required ({String id}) pointer,
    required List<String> path,
    required Map<String, dynamic> args,
  }) = _Operation;

  const Operation._();
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum OperationType {
  set(dbName: 'set');

  const OperationType({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum ArgKey {
  id(dbName: 'id'),
  type(dbName: 'type'),
  properties(dbName: 'properties'),
  createdAt(dbName: 'createdAt'),
  lastEditedAt(dbName: 'lastEditedAt');

  const ArgKey({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}
