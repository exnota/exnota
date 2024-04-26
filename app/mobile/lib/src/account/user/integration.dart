import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'integration.freezed.dart';

const collectionIntegration = 'integration';
const integrationFieldType = 'type';

enum IntegrationType {
  notion(fieldName: 'notion'),
  unknown(fieldName: 'unknown');

  const IntegrationType({required this.fieldName});

  final String fieldName;

  @override
  String toString() => fieldName;
}

@freezed
class Integration with _$Integration {
  const factory Integration({
    required String id,
    required IntegrationType type,
  }) = _Integration;

  factory Integration.fromRecord(RecordModel record) {
    final data = record.data;
    final type = IntegrationType.values.firstWhere(
      (type) => type.fieldName == data[integrationFieldType],
      orElse: () => IntegrationType.unknown,
    );

    return Integration(
      id: record.id,
      type: type,
    );
  }
}
