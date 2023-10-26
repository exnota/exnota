import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'environment_service.g.dart';

enum Environment { local, prod }

@Riverpod(keepAlive: true)
class EnvironmentService extends _$EnvironmentService {
  @override
  Environment build() {
    return Environment.prod;
  }

  void setEnvironment(Environment environment) {
    state = environment;
  }
}
