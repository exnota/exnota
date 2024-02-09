import 'package:exnota/src/account/settings/settings_service.dart';
import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/lib/env/device_info.dart';
import 'package:flutter/material.dart';
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
class MockLocalSettingsService extends _$MockLocalSettingsService
    implements SettingsService {
  @override
  Future<Settings> build() async {
    return const Settings(
      themeMode: ThemeMode.system,
      environment: Environment.local,
    );
  }

  @override
  Future<void> setEnvironment(Environment? environment) async {}

  @override
  Future<void> setThemeMode(ThemeMode? themeMode) async {}
}

@Riverpod(keepAlive: true)
class MockProdSettingsService extends _$MockProdSettingsService
    implements SettingsService {
  @override
  Future<Settings> build() async {
    return const Settings(
      themeMode: ThemeMode.system,
      environment: Environment.prod,
    );
  }

  @override
  Future<void> setEnvironment(Environment? environment) async {}

  @override
  Future<void> setThemeMode(ThemeMode? themeMode) async {}
}

void main() {
  group('uri service', () {
    group('given a local environment', () {
      group('and a non-android platform', () {
        test('it returns the correct uri', () async {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            settingsServiceProvider
                .overrideWith(() => MockLocalSettingsService()),
            deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
              const deviceInfo = DeviceInfo(
                  isPhysicalDevice: true, isAndroid: false, isIos: true);
              return deviceInfo;
            })
          ]);

          // Eagerly load settings the uri service can use requireValue on it.
          await container.read(settingsServiceProvider.future);

          // Eagerly load settings the uri service can use requireValue on it.
          await container.read(settingsServiceProvider.future);

          expect(
            container.read(uriServiceProvider),
            equals(Uri.http('localhost:8080')),
          );
        });
      });
      group('and an android simulator platform', () {
        test('it returns the correct uri', () async {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            settingsServiceProvider
                .overrideWith(() => MockLocalSettingsService()),
            deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
              const deviceInfo = DeviceInfo(
                  isPhysicalDevice: false, isAndroid: true, isIos: false);
              return deviceInfo;
            })
          ]);

          // Eagerly load settings the uri service can use requireValue on it.
          await container.read(settingsServiceProvider.future);

          expect(
            container.read(uriServiceProvider),
            equals(Uri.http('10.0.2.2:8080')),
          );
        });
      });
      group('and an android physical device platform', () {
        test('it returns the correct uri', () async {
          // DO NOT share ProviderContainers between tests.
          final container = createContainer(overrides: [
            settingsServiceProvider
                .overrideWith(() => MockLocalSettingsService()),
            deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
              const deviceInfo = DeviceInfo(
                  isPhysicalDevice: true, isAndroid: true, isIos: false);
              return deviceInfo;
            })
          ]);

          // Eagerly load settings the uri service can use requireValue on it.
          await container.read(settingsServiceProvider.future);

          expect(
            container.read(uriServiceProvider),
            equals(Uri.http('127.0.0.1:8080')),
          );
        });
      });
    });
    group('given a prod environment', () {
      test('it returns the correct uri', () async {
        // DO NOT share ProviderContainers between tests.
        final container = createContainer(overrides: [
          settingsServiceProvider.overrideWith(() => MockProdSettingsService()),
          deviceInfoProvider.overrideWith((DeviceInfoRef ref) {
            const deviceInfo = DeviceInfo(
                isPhysicalDevice: true, isAndroid: true, isIos: false);
            return deviceInfo;
          })
        ]);

        // Eagerly load settings the uri service can use requireValue on it.
        await container.read(settingsServiceProvider.future);

        expect(
          container.read(uriServiceProvider),
          equals(Uri.https('exnota.matt.to')),
        );
      });
    });
  });
}
