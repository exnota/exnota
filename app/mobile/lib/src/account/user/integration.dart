import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'integration.freezed.dart';

const collectionIntegration = 'integration';
const integrationFieldType = 'type';
const integrationFieldConfig = 'config';
const integrationFieldUser = 'user';
const integrationFieldStatus = 'status';

enum IntegrationType {
  notion(fieldName: 'notion'),
  unknown(fieldName: 'unknown');

  const IntegrationType({required this.fieldName});

  final String fieldName;

  @override
  String toString() => fieldName;
}

const integrationStatusConnected = 'connected';

@freezed
class Integration with _$Integration {
  const factory Integration({
    required String id,
    required IntegrationType type,
  }) = _Integration;

  const Integration._();

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

  static Map<String, dynamic> createNotionIntegrationRequestBody({
    required IntegrationType type,
    required String code,
    required String userId,
  }) {
    Map<String, dynamic> body = {
      integrationFieldType: type.toString(),
      integrationFieldConfig: {
        'auth': {
          'code': code,
        }
      },
      integrationFieldUser: userId,
      integrationFieldStatus: integrationStatusConnected,
    };

    return body;
  }

  static Map<String, dynamic> updateNotionIntegrationRequestBody({
    required String code,
  }) {
    Map<String, dynamic> body = {
      integrationFieldConfig: {
        'auth': {
          'code': code,
        }
      },
    };

    return body;
  }
}
