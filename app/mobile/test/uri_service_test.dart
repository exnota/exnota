import 'package:exnota/src/account/settings/environment_service.dart';
import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/lib/env/device_info.dart';
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
  group('uri service', () {
    group('given a local environment', () {
      group('and a non-android platform', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockLocalEnvironmentService()),
            deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
              const deviceInfo = DeviceInfo(
                  isPhysicalDevice: true, isAndroid: false, isIos: true);
              return deviceInfo;
            })
          ]);

          expect(
            container.read(uriServiceProvider),
            equals(Uri.http('localhost:8080')),
          );
        });
      });
      group('and an android simulator platform', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockLocalEnvironmentService()),
            deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
              const deviceInfo = DeviceInfo(
                  isPhysicalDevice: false, isAndroid: true, isIos: false);
              return deviceInfo;
            })
          ]);

          expect(
            container.read(uriServiceProvider),
            equals(Uri.http('10.0.2.2:8080')),
          );
        });
      });
      group('and an android physical device platform', () {
        test('it returns the correct uri', () {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            environmentServiceProvider
                .overrideWith(() => MockLocalEnvironmentService()),
            deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
              const deviceInfo = DeviceInfo(
                  isPhysicalDevice: true, isAndroid: true, isIos: false);
              return deviceInfo;
            })
          ]);

          expect(
            container.read(uriServiceProvider),
            equals(Uri.http('127.0.0.1:8080')),
          );
        });
      });
    });
    group('given a prod environment', () {
      test('it returns the correct uri', () {
        // DO NOT share ProviderContainers between tests.
        final container = createContainer(overrides: [
          environmentServiceProvider
              .overrideWith(() => MockProdEnvironmentService()),
          deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
            const deviceInfo = DeviceInfo(
                isPhysicalDevice: true, isAndroid: true, isIos: false);
            return deviceInfo;
          })
        ]);

        expect(
          container.read(uriServiceProvider),
          equals(Uri.https('exnota.matt.to')),
        );
      });
    });
  });
}
