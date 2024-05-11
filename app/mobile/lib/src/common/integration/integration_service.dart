import 'dart:async';

import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/integration/service/integration_writer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'integration_service.g.dart';

@Riverpod()
class IntegrationService extends _$IntegrationService {
  @override
  void build() {
    // no-op
  }

  Future<BasicResponse<void>> syncIntegrationDestinations(
      {required String integrationId}) async {
    return await ref
        .read(integrationWriterProvider.notifier)
        .syncIntegrationDestinations(integrationId: integrationId);
  }
}
