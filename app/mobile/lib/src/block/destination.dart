// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'destination.freezed.dart';
part 'destination.g.dart';

const collectionDestination = 'destination';
const destinationFieldWorkspace = 'workspace';

@freezed
class Destination with _$Destination {
  const factory Destination({
    required String id,
    String? name,
    required String workspaceId,
    DestinationExternal? external,
    required String userId,
    DateTime? created,
    DateTime? updated,
  }) = _Destination;

  const Destination._();

  factory Destination.fromRecord(RecordModel model) {
    DestinationExternal? external;
    final externalMap = model.data['external'];
    if (externalMap != null && externalMap is Map<String, dynamic>) {
      external = DestinationExternal.fromJson(externalMap);
    }

    return Destination(
      id: model.id,
      name: model.data['name'],
      workspaceId: model.data[destinationFieldWorkspace],
      external: external,
      userId: model.data['user'],
      created: DateTime.tryParse(model.created),
      updated: DateTime.tryParse(model.updated),
    );
  }
}

enum DestinationExternalNotionStatus {
  connected,
  notFound,
  archived,
  unknownError,
  rateLimited,
  unknown,
}

// The external field is import only, so it doesn't matter we modify an unknown
// status or other data, e.g. an unknown status to DestinationExternalNotionStatus.unknown.
@freezed
class DestinationExternal with _$DestinationExternal {
  const factory DestinationExternal({DestinationExternalNotionStatus? status}) =
      _DestinationExternal;

  const DestinationExternal._();

  factory DestinationExternal.fromJson(Map<String, dynamic> json) =>
      _$DestinationExternalFromJson(json);
}
