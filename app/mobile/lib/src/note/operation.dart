// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'operation.freezed.dart';
part 'operation.g.dart';

@freezed
class Operation with _$Operation {
  const factory Operation({
    @JsonKey(name: 'type') required OperationType type,
    @JsonKey(name: 'pointer') required ({String id}) pointer,
    @JsonKey(name: 'path') required List<String> path,
    @JsonKey(name: 'args') required Map<String, dynamic> args,
  }) = _Operation;

  const Operation._();

  factory Operation.fromJson(Map<String, dynamic> json) =>
      _$OperationFromJson(json);
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum OperationType {
  listAfter(dbName: 'listAfter'),
  set(dbName: 'set'),
  update(dbName: 'update');

  const OperationType({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum ListAfterArg {
  after(dbName: 'after'),
  id(dbName: 'id');

  const ListAfterArg({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum Prop {
  id(dbName: 'id'),
  type(dbName: 'type'),
  properties(dbName: 'properties'),
  external(dbName: 'external'),
  content(dbName: 'content'),
  parentId(dbName: 'parentId'),
  createdAt(dbName: 'createdAt'),
  lastEditedAt(dbName: 'lastEditedAt');

  const Prop({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum PrepExternal {
  url(dbName: 'url');

  const PrepExternal({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}

@JsonEnum(alwaysCreate: true, valueField: 'dbName')
enum SingleVal {
  val(dbName: 'val');

  const SingleVal({required this.dbName});

  final String dbName;

  @override
  String toString() => dbName;
}
