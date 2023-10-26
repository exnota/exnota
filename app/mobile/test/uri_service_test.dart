import 'package:exnota/src/account/settings/environment_service.dart';
import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'uri_service_test.g.dart';

ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  addTearDown(container.dispose);

  return container;
}

@Riverpod(keepAlive: true)
class MockLocalEnvironmentService extends _$MockLocalEnvironmentService
    implements EnvironmentService {
  @override
  Environment build() {
    return Environment.local;
  }

  @override
  void setEnvironment(Environment environment) {}
}

@Riverpod(keepAlive: true)
class MockProdEnvironmentService extends _$MockProdEnvironmentService
    implements EnvironmentService {
  @override
  Environment build() {
    return Environment.prod;
  }

  @override
  void setEnvironment(Environment environment) {}
}

void main() {
  group('environment service', () {
    group('given a local environment', () {
      group('and a non-android platform', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockLocalEnvironmentService())
          ]);
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

          expect(
            container.read(uriServiceProvider(path: 'test/path')),
            equals(Uri.http('localhost:3000', "test/path")),
          );
        });
      });
      group('and an android platform', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockLocalEnvironmentService())
          ]);
          debugDefaultTargetPlatformOverride = TargetPlatform.android;

          expect(
            container.read(uriServiceProvider(path: 'test/path')),
            equals(Uri.http('10.0.2.2:3000', "test/path")),
          );
        });
      });
    });
    group('given a prod environment', () {
      group('when noApi is not set', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockProdEnvironmentService())
          ]);

          expect(
            container.read(uriServiceProvider(path: 'test/path')),
            equals(Uri.https('exnota.com', "api/test/path")),
          );
        });
      });
      group('when noApi is set', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockProdEnvironmentService())
          ]);

          expect(
            container.read(uriServiceProvider(path: 'test/path', noApi: true)),
            equals(Uri.https('exnota.com', "test/path")),
          );
        });
      });
      group('when no path is provided', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockProdEnvironmentService())
          ]);

          expect(
            container.read(uriServiceProvider()),
            equals(Uri.https('exnota.com')),
          );
          expect(
            container.read(uriServiceProvider(noApi: true)),
            equals(Uri.https('exnota.com')),
          );
        });
      });
    });
  });
}
